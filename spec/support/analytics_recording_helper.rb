module AnalyticsRecordingHelper
  PATHS_TO_STRIP_WHEN_RECORDING = [
    %i[properties browser_bot],
    %i[properties browser_device_name],
    %i[properties browser_mobile],
    %i[properties browser_name],
    %i[properties browser_platform_name],
    %i[properties browser_platform_version],
    %i[properties browser_version],
    %i[properties git_branch],
    %i[properties git_sha],
    %i[properties hostname],
    %i[properties pid],
    %i[properties session_duration],
    %i[properties trace_id],
    %i[properties user_agent],
    %i[properties user_ip],
  ].freeze

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

  SHA_256_HASH_REGEX = /\A[0-9a-f]{64}\z/

  ISO_8601_REGEX = /\A\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}(\.\d+)Z\z/

  LOCALHOST_URL_WITH_HIGH_PORT = /\Ahttp:\/\/(localhost|127\.0\.0\.1):(\d+)/

  # Tokenizers take path + value in and return either:
  # - nil to not tokenize
  # - True to tokenize using the key of the TOKENIZERS array as a namespace
  # - String or Symbol to customize the namespace of the token
  TOKENIZERS = {
    database_id: ->(path, value) {
      looks_like_id = path.last == :id || path.last.to_s.end_with?('_id')

      return if !looks_like_id
      return if !value.is_a?(Integer)

      # Use just the last component of the path as the token namespace,
      # e.g. email_address_id
      path.last
    },
    sha_256_hash: ->(_path, value) {
      value.is_a?(String) && SHA_256_HASH_REGEX.match?(value)
    },
    uuid: ->(_path, value) {
      value.is_a?(String) && UUID_REGEX.match?(value)
    },
    domain_name: ->(path, value) {
      # This varies in the "User Registration: Email Submitted" event
      value.is_a?(String) && path.last == :domain_name
    },
  }.freeze

  # Normalizers take a path + value in and return the normalized value
  NORMALIZERS = {
    millisecond_values: ->(path, value) {
      return value if !path.last.to_s.end_with?('_in_ms')
      return value if !value.is_a?(Numeric)

      # Round to nearest second
      (value / 1000.0).round * 1000
    },
    ignore_ssn_is_unique: ->(path, value) {
      # Verify proofing results event logs this, a unique SSN during recording
      # may not stay unique in subsequent runs.
      return if path.last == :ssn_is_unique

      value
    },
    ignore_timestamps: ->(path, value) {
      return value if !path.last.to_s.end_with?('_at')
      return  if value.is_a?(Time)
      return  if ISO_8601_REGEX.match?(value.to_s)
      value
    },
    second_values: ->(path, value) {
      return value if !path.last.to_s.end_with?('_in_seconds')
      return value if !value.is_a?(Numeric)

      # Round to nearest 10 seconds
      (value / 10.0).round * 10
    },
    localhost_url_referencing_high_port: ->(_path, value) {
      if value.is_a?(String)
        value.gsub(LOCALHOST_URL_WITH_HIGH_PORT, 'http://localhost:11223344')
      end
      value
    },
  }

  EVENT_CONTEXT_GIVERS = [
    ->(event) {
      event.dig(:properties, :event_properties, :action)
    },
    ->(event) {
      success = event.dig(:properties, :event_properties, :success)
      if success == true
        'succeeded'
      elsif success == false
        'failed'
      end
    },
  ].freeze

  # Either:
  # 1) Records analytics events logged during {block} when the RECORD_ANALYTICS env is truthy OR
  # 2) Verifies analytics events logged during {block} against previously-recorded events
  # @param {String} file_name File to record analytics events to
  def record_and_verify_analytics(
    file_name:,
    &block
  )
    if should_record_analytics?
      record_analytics(file_name:, &block)
      raise <<~END
        Recorded analytics events to '#{file_name}'. 
        This error was raised to ensure this test run doesn't succeed.
        Re-run the tests without RECORD_ANALYTICS set.
      END
    else
      assert_logged_analytics_events_match_file(file_name:, &block)
    end
  end

  # Verifies that the analytics events logged during the execution of block
  # "match" those present in the given file.
  def assert_logged_analytics_events_match_file(
    file_name:,
    &block
  )
    expected_events = load_analytics_events_from_file(file_name:)
    assert_logged_analytics_events_match(expected_events:, file_name:, &block)
  end

  # Verifies that the analytics events logged during the execution of {block}
  # match those present in {expected_events}
  # @param [Hash[]] expected_events Array of analytics event hashes.
  # @param [Number] window_size Number of events we look at when trying to find a match.
  def assert_logged_analytics_events_match(
    expected_events:,
    window_size: 5,
    file_name: nil,
    &block
  )
    actual_events = []
    middleware = proc { |event| actual_events << event }

    Analytics.with_default_middleware(middleware) do
      block.call
    end

    normalized_actual_events = actual_events.map do |e|
      normalize_logged_analytics_event(e)
    end

    normalized_expected_events = expected_events.map do |e|
      normalize_logged_analytics_event(e)
    end

    already_matched_indices = []

    normalized_actual_events.each_with_index do |actual_event, index|
      start_index = [index - (window_size / 2), 0].max
      end_index = [index + (window_size / 2)].min

      candidates = normalized_expected_events[start_index..end_index]

      # We expect that {actual_event} will match _one_ of these candidates
      matched = false
      close_match_index = nil

      candidates.each_with_index do |c, candidate_index|
        index_in_main_list = start_index + candidate_index
        next if already_matched_indices.include?(index_in_main_list)

        if c == actual_event
          matched = true
          already_matched_indices << index_in_main_list
          break
        end

        if c[:name] == actual_event[:name]
          close_match_index = index_in_main_list
        end
      end

      next if matched

      # If we have an event we _think_ might be the one we're trying to match,
      # we can delegate to Rspec for error messaging.
      if close_match_index.present?
        expect(actual_event).to eql(normalized_expected_events[close_match_index])
      end

      error_message = <<~END
        Failed to match #{summarize_event(actual_event)}

        The event that was logged looks like this:

        #{actual_event.pretty_inspect}

        Here are the events _around_ where we thought it should be:

        #{candidates.map do |c| 
          lines = c.pretty_inspect.split("\n")
          [
            "- #{lines.first}",
            *lines.drop(1).map { |l| l.indent(2) },
          ].join("\n")
        end.join("\n")}
      END

      if file_name.present?
        error_message = <<~END
          #{error_message}
          
          Reference #{file_name} to see the full list of expected events.
        END
      end

      expect(matched).to eql(true), error_message
    end

    if !normalized_expected_events.empty?
      count = normalized_expected_events.count
      raise "There #{count == 1 ? "was" : "were"} #{count} expected event#{count == 1 ? "" : "s"} that were not logged"
    end
  end

  def load_analytics_events_from_file(file_name:)
    File.foreach(file_name).each_with_index.map do |line, line_number|
      next if line.blank?

      event = begin
        JSON.parse(line).tap do |event|
          raise 'Line does not contain a JSON object' if !event.is_a?(Hash)
        end
      rescue => error
        raise "#{file_name}:#{line_number}: #{error}"
      end

      # Allow "comments" so we can put a header in this file when recording
      # without violating the ndjson spec.
      next if event.has_key?('//')

      event
    end.compact
  end

  # When recording, we need to ensure that the given event is converted to
  # a structure that can be cleanly serialized as JSON
  def prepare_analytics_event_for_record(event)
    prepare_part_of_analytics_event_for_record(event)
  end

  # TODO: can this ^ and v that be replaced with .as_json

  def prepare_part_of_analytics_event_for_record(value)
    if value.is_a?(Numeric)
      value
    elsif value.is_a?(TrueClass) || value.is_a?(FalseClass)
      value
    elsif value.is_a?(Symbol)
      value.to_s
    elsif value.is_a?(String)
      value
    elsif value.nil?
      nil
    elsif value.is_a?(Array)
      value.map { |v| prepare_part_of_analytics_event_for_record(v) }
    elsif value.is_a?(Hash)
      value.map do |key, value|
        [key.to_sym, prepare_part_of_analytics_event_for_record(value)]
      end.to_h.compact
    elsif value.respond_to?(:to_h)
      prepare_part_of_analytics_event_for_record(value.to_h)
    elsif value.respond_to?(:as_json)
      prepare_part_of_analytics_event_for_record(value.as_json)
    else
      name = event[:name]
      raise "Can't record event '#{name}': invalid value at #{path.join(".")} (#{value.inspect})"
    end
  end

  def normalize_logged_analytics_event(event)
    normalized_event = normalize_part_of_analytics_event(event)
    strip_irrelevant_paths_from_event(normalized_event)

    json = JSON.generate(normalized_event)
    JSON.parse(json, symbolize_names: true)
  end

  # Takes a value extracted from an analytics event and tries to normalize it.
  # @param [Object] value Value to be normalized
  # @param [Symbol[]] path Path to this value in the event
  # @param [Hash] state Holds state used for normalization
  def normalize_part_of_analytics_event(value, path = [], state = {})
    if value.is_a?(Numeric)
      value
    elsif value.is_a?(TrueClass) || value.is_a?(FalseClass)
      value
    elsif value.is_a?(Symbol)
      value.to_s
    elsif value.is_a?(String)
      value
    elsif value.nil?
      nil
    elsif value.is_a?(Array)
      value.map { |v| normalize_part_of_analytics_event(v, path, state) }
    elsif value.is_a?(Hash)
      value.map do |key, value|
        key_as_symbol = key.to_sym
        new_value = normalize_hash_key_value(value, [*path, key_as_symbol], state)
        [key_as_symbol, new_value]
      end.to_h.compact
    elsif value.respond_to?(:to_h)
      normalize_part_of_analytics_event(value.to_h, path, state)
    elsif value.respond_to?(:as_json)
      normalize_part_of_analytics_event(value.as_json, path, state)
    else
      name = event[:name]
      parenthetical = path.empty? ? '' : " (#{path.join(".")})"
      raise "Error in '#{name}'#{parenthetical}: Can't normalize #{value.inspect}"
    end
  end

  def normalize_hash_key_value(value, path, state)
    TOKENIZERS.each do |tokenizer_name, tokenizer|
      tokenizer_result = tokenizer.call(path, value)

      next if !tokenizer_result

      # "token_type" is the namespace in which this token will live.
      # By default, we use a global namespace. But if {tokenizer}
      # returned a symbol / string, we use that.
      # This is because some IDs are safe to put in a global namespace
      # because we won't have collisions (like UUIDs). Other things
      # (like database ids) aren't unique enough, so we need a hint
      # as to their context (essentially "what database table is this
      # numeric ID from?")

      token_type = tokenizer_result == true ?
        tokenizer_name.to_s :
        tokenizer_result.to_s

      state[:tokenizers] ||= {}
      state[:tokenizers][token_type] ||= {}

      tokens = state[:tokenizers][token_type]

      if !tokens.has_key?(value)
        tokens[value] = "#{token_type}:#{tokens.count + 1}"
      end

      return tokens[value]
    end

    NORMALIZERS.each_value do |normalizer|
      normalized = normalizer.call(path, value)
      return normalized if normalized != value
    end

    # If we didn't apply tokenization, then continue processing normally
    normalize_part_of_analytics_event(value, path, state)
  end

  # Records any analytics events logged during the execution of the given
  # block to a file.
  # @param [String] file_name
  def record_analytics(
    file_name:,
    &block
  )
    file_handle = nil

    # Record to a temp file so we don't clobber good events if an error is raised
    temp_file = "#{file_name}.tmp"

    FileUtils.mkdir_p(File.dirname(temp_file))
    file_handle = File.open(temp_file, 'w')

    file_handle.write(
      JSON.generate(
        { "//": "This file was generated on #{Time.zone.now}" },
      ), "\n"
    )

    recording_middleware = proc do |event|
      event_to_record = prepare_analytics_event_for_record(event)
      strip_irrelevant_paths_from_event(event_to_record)
      file_handle.write(JSON.generate(event_to_record), "\n")
    end

    Analytics.with_default_middleware(recording_middleware) do
      block.call
    end

    File.rename(temp_file, file_name)
  rescue
    begin
      h = file_handle
      file_handle = nil

      h&.close
      File.unlink(temp_file)
    end

    raise
  ensure
    file_handle&.close
  end

  def should_record_analytics?
    ActiveModel::Type::Boolean.new.cast(ENV['RECORD_ANALYTICS'])
  end

  private

  # @param [Hash] event
  def strip_irrelevant_paths_from_event(event)
    PATHS_TO_STRIP_WHEN_RECORDING.each do |path|
      parent_path = path.take(path.length - 1)
      parent = parent_path.empty? ? event : event.dig(*parent_path)
      parent.delete(path.last) if parent.is_a?(Hash)
    end
  end

  def summarize_event(event)
    name = event[:name]
    context = EVENT_CONTEXT_GIVERS.map { |g| g.call(event) }.compact
    return name if context.empty?

    "#{name} (#{context.join("; ")})"
  end
end
