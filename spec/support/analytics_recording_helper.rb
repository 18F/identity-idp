module AnalyticsRecordingHelper
  def self.included(base)
    base.class_eval do
      around do |ex|
        file_name =
          "spec/fixtures/analytics/analytics-events-#{ex.full_description.parameterize}.ndjson"

        status = record_or_verify_analytics(file_name:) do
          ex.run
        end

        case status
        when :checked then puts "Compared analytics events to #{file_name}"
        when :recorded then puts "Recorded analytics events to #{file_name}}"
        end
      end
    end
  end

  PATHS_TO_STRIP_WHEN_RECORDING = [
    # These paths contain metadata that will either not contain useful values
    # for test purposes OR will contain values that are unstable enough that
    # they'd break tests left and right.
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

    # This is logged by the 'IdV: doc auth verify proofing results' event.
    # Because we use fixtures for our tests, this value is not particularly
    # meaningful (it may be `true` during recording but `false` on subsequent
    # runs [or vice versa]).
    %i[properties event_properties proofing_results ssn_is_unique],
  ].freeze

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

  SHA_256_HASH_REGEX = /\A[0-9a-f]{64}\z/

  ISO_8601_REGEX = /\A\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}(\.\d+)Z\z/

  # Tokenizers take path + value in and return either:
  # - nil to not tokenize
  # - True to tokenize using the key of the TOKENIZERS array as a namespace
  # - A String or Symbol to customize the namespace used for the token
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
    url_with_state: ->(_path, value) {
      return if !value.is_a?(String)

      uri = begin
        URI(value)
      rescue URI::InvalidURIError
        return
      end

      !!/(^|&)state=[a-f0-9]+/.match?(uri.query)
    },
  }.freeze

  # Normalizers take a path + value in and return the normalized value for that path.
  NORMALIZERS = {
    ignore_timestamps: ->(path, value, _state) {
      return value if !path.last.to_s.end_with?('_at')
      return '<TIMESTAMP>' if ISO_8601_REGEX.match?(value.to_s)

      if (value.is_a?(Numeric) || /\A\d+\z/.match?(value)) && value.to_i > 1704096000
        return '<UNIX TIMESTAMP>'
      end

      value
    },
    localhost_url_referencing_weird_port: ->(_path, value, _state) {
      # During feature specs, the Rails app runs on localhost with a high
      # random port number that will vary between runs.
      if value.is_a?(String)
        uri = begin
          URI(value)
        rescue URI::InvalidURIError
          return value
        end

        return value if !uri.is_a?(URI::HTTP)
        return value if uri.port == 80

        uri.port = 1234
        return uri.to_s
      end

      value
    },
    round_millisecond_values: ->(path, value, _state) {
      return value if !path.last.to_s.end_with?('_ms')
      return value if !value.is_a?(Numeric)

      # Round to nearest 10 seconds
      rounded = (value / 10000.0).round * 10000
      "#{rounded}ish"
    },
    round_second_values: ->(path, value, _state) {
      return value if !path.last.to_s.end_with?('_seconds')
      return value if !value.is_a?(Numeric)

      # Round to nearest minute
      rounded = (value / 60.0).round * 60
      "#{rounded}ish"
    },
    symbols_to_strings: ->(_path, value, _state) {
      if value.is_a?(Symbol)
        value.to_s
      else
        value
      end
    },
    tokenize: ->(path, value, state) {
      TOKENIZERS.each do |tokenizer_name, tokenizer|
        tokenizer_result = tokenizer.call(path, value)

        next if !tokenizer_result

        # "token_type" is the namespace in which this token will live.
        # By default, we use a namespace shared by all items handled by this
        # tokenizer. But if {tokenizer} returns a Symbol / String, we use that
        # as the namespace.
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

      value
    },
  }

  # These are used when generating a friendly summary of an event to provide
  # short bits of additional context.
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
  # @return {Symbol,nil} Either :recorded (if analytics were recorded) or :checked (if events were
  #                      checked against a previous recording. If no recorded events could b
  #                      found to check against, returns nil.
  def record_or_verify_analytics(
    file_name:,
    &block
  )
    if should_record_analytics?
      record_analytics(file_name:, &block)
      return :recorded
    end

    actual_events = []
    middleware = proc { |event| actual_events << event }

    Analytics.with_default_middleware(middleware) do
      block.call
    end

    expected_events = begin
      load_analytics_events_from_file(file_name:)
    rescue Errno::ENOENT
      return nil
    end

    assert_logged_analytics_events_match(
      actual_events:,
      expected_events:,
      file_name:,
    )

    :checked
  end

  # Verifies that {actual_events} matches {expected_events}.
  # Order matters, but some wiggle room is allowed via the {window_size} parameter.
  # @param [Hash[]] actual_events Array of actual events logged.
  # @param [Hash[]] expected_events Array of analytics event hashes.
  # @param [String,nil] file_name File name events were loaded from (for error reporting)
  # @param [Number] window_size Number of events we look at when trying to find a match.
  def assert_logged_analytics_events_match(
    actual_events:,
    expected_events:,
    file_name: nil,
    window_size: 5
  )
    actual_events = actual_events.map do |e|
      normalize_analytics_event_for_comparison(e)
    end

    expected_events = expected_events.map do |e|
      normalize_analytics_event_for_comparison(e)
    end

    # key = index in expected_events, value = index in actual_events
    matches = {}

    actual_events.each_with_index do |actual_event, actual_event_index|
      start_index = [actual_event_index - (window_size / 2), 0].max
      end_index = [actual_event_index + (window_size / 2), expected_events.length - 1].min

      candidates = expected_events[start_index..end_index]

      candidates.each_with_index do |expected_event, candidate_index|
        expected_event_index = start_index + candidate_index
        already_matched = matches.has_key?(expected_event_index)
        next if already_matched

        if expected_event == actual_event
          matches[expected_event_index] = actual_event_index
          break
        end
      end

      next if matches.value?(actual_event_index)

      asserted = false

      # If there is 1 event matching by name in the candidate set, do a
      # basic expect().to eql() type operation on it to hopefully get a good
      # diff in the output.
      closest_matches = candidates.filter { |e| e[:name] == actual_event[:name] }
      if closest_matches.length == 1
        expect(actual_event).to eql(closest_matches.first), error_message(<<~ERROR, file_name:)
          No match was found for the event #{summarize_event(actual_event)} in the fixture data.
        ERROR
        asserted = true
      end

      next if asserted

      expect('event matched').to eql('event not matched'), error_message(<<~ERROR, file_name:)
        Event '#{summarize_event(actual_event)}' was logged, but not expected.

        Here are the events we expected around where it happened:
        #{candidates.each_with_index.map do |c, candidate_index| 
          expected_event_index = start_index + candidate_index
          matched_to = matches[expected_event_index]
          "- #{summarize_event(c)}#{matched_to ? " (matched to ##{matched_to})" : ""}" 
        end.join("\n")}
      ERROR
    end

    unmatched_expected_events =
      (Set.new(0..expected_events.length - 1) - matches.keys.to_set)
        .map { |index| expected_events[index] }

    expect(unmatched_expected_events.length).to eql(0), error_message(<<~ERROR, file_name:)
      The following events were expected, but not seen:

      #{unmatched_expected_events.map { |e| "- #{summarize_event(e)}" }.join("\n")}
    ERROR
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

  # Normalizes {event} so that it can be directly compared to other events.
  def normalize_analytics_event_for_comparison(event)
    event = JSON.parse(event.to_json, symbolize_names: true)

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
    if value.is_a?(Hash)
      return value.map do |key, value|
        new_value = normalize_part_of_analytics_event(value, [*path, key], state)
        [key.to_sym, new_value]
      end.to_h.compact
    elsif value.is_a?(Array)
      return value.each_with_index.map do |v, index|
        normalize_part_of_analytics_event(v, [*path, index], state)
      end
    end

    NORMALIZERS.each do |_normalizer_name, normalizer|
      value = normalizer.call(path, value, state)
    end

    value
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
      event_to_record = JSON.parse(event.to_json, symbolize_names: true)
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

  def error_message(message, file_name: nil)
    message = <<~ERROR
      #{message}

      If you think this error should not have happened, it might mean that the
      fixture data is out-of-date. You can regenerate it by re-running
      your tests with the RECORD_ANALYTICS=true, e.g.:

        RECORD_ANALYTICS=true bundle exec rspec path/to/your/spec.rb

    ERROR

    if file_name.present?
      message = <<~ERROR
        #{message}
        
        (Fixture data was loaded from #{file_name}.)
      ERROR
    end

    message
  end

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

    "\"#{name}\" (#{context.join("; ")})"
  end
end
