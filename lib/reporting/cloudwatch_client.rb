require 'aws-sdk-cloudwatchlogs'

module Reporting
  class CloudwatchClient
    DEFAULT_NUM_THREADS = 5
    DEFAULT_WAIT_DURATION = 3
    MAX_RESULTS_LIMIT = 10_000

    attr_reader :num_threads, :wait_duration, :slice_interval, :logger, :log_group_name

    # @param [Boolean] ensure_complete_logs when true, will detect when queries return exactly
    #  10,000 rows (Cloudwatch Insights max limit) and then recursively split the query window into
    #  two queries until we're certain we've queried all rows
    # @param [ActiveSupport::Duration,#to_i,Boolean,nil] slice_interval How to slice up the query
    #  over time.
    #  * Pass an Integer (number of seconds) or an ActiveSupport::Duration such as 1.day to slice up
    #    the query by that number of seconds
    #  * Pass something falsy to indicate skip to slicing the query
    # @param [Boolean,nil,IO,#fileno] progress whether or not to show progress, and which IO
    #  to send send the progress bar to (defaults to STDERR)
    def initialize(
      ensure_complete_logs: true,
      num_threads: DEFAULT_NUM_THREADS,
      wait_duration: DEFAULT_WAIT_DURATION,
      slice_interval: 1.day,
      logger: nil,
      progress: true,
      log_group_name: default_events_log
    )
      @ensure_complete_logs = ensure_complete_logs
      @num_threads = num_threads
      @wait_duration = wait_duration
      @slice_interval = slice_interval
      @logger = logger
      @progress = progress
      @log_group_name = log_group_name
    end

    # Either both (from, to) or time_slices must be provided
    # @param [#to_s] query
    # @param [Time] from
    # @param [Time] to
    # @param [Array<Range<Time>>] time_slices Pass an to use specific slices
    # @raise [ArgumentError] raised when incorrect time parameters are received
    # @overload fetch(query:, from:, to:)
    #   The block-less form returns the array of *all* results at the end
    #   @return [Array<Hash>]
    # @overload fetch(query: time_slices:) { |row| "..." }
    #   The block form yields each result row as its ready to the block and returns nil
    #   @yieldparam [Hash] row a row of the query result
    #   @return [nil]
    def fetch(query:, from: nil, to: nil, time_slices: nil)
      results = Concurrent::Array.new if !block_given?
      each_result_queue = Queue.new if block_given?
      in_progress = Concurrent::Hash.new(0)

      # Time slices to query, a tuple of range_to_query, range_id [Range<Time>, Integer]
      # we track the number of live threads by how many jobs connected to each range_id
      # are still working
      queue = Queue.new

      slice_time_range(from:, to:, time_slices:).each_with_index.map do |range, range_id|
        in_progress[range_id] += 1
        queue << [range, range_id]
      end

      if show_progress?
        @progress_bar = ProgressBar.create(
          starting_at: 0,
          total: queue.size,
          format: 'Querying log slices %j%% [%c/%C] |%B| %a',
          output: @progress.respond_to?(:fileno) ? @progress : STDERR,
        )
      end

      log(:debug, "starting query, queue_size=#{queue.length} num_threads=#{num_threads}")
      log(:info, "=== query ===\n#{query}\n=== query ===")

      # rubocop:disable Metrics/BlockLength
      threads = num_threads.times.map do |thread_idx|
        Thread.new do
          while (range, range_id = queue.pop)
            start_time = range.begin.to_i
            end_time = range.end.to_i

            response = fetch_one(query:, start_time:, end_time:)
            @progress_bar&.increment

            if ensure_complete_logs? && has_more_results?(response.results.size)
              log(:info, "more results, bisecting: start_time=#{start_time} end_time=#{end_time}")
              mid = midpoint(start_time:, end_time:)

              # -1 for current work finishing, +2 for new threads enqueued
              in_progress[range_id] += 1

              @progress_bar&.total += 2

              queue << [(start_time..(mid - 1)), range_id]
              queue << [(mid..end_time), range_id]
            else
              log(:debug, "worker finished, slice_duration=#{end_time - start_time}")
              in_progress[range_id] -= 1
              parsed_results = parse_results(response.results)

              results&.concat(parsed_results)
              if each_result_queue
                parsed_results.each do |row|
                  each_result_queue << row
                end
              end
            end
          end

          log(:debug, "thread done thread_idx=#{thread_idx}")

          nil
        end.tap do |thread|
          thread.abort_on_exception = true
        end
      end
      # rubocop:enable Metrics/BlockLength

      if each_result_queue
        result_thread = Thread.new do
          while (row = each_result_queue.pop)
            yield row
          end
        end
      end

      until (num_in_progress = in_progress.sum(&:last)).zero?
        @progress_bar&.refresh
        log(:debug, "waiting, num_in_progress=#{num_in_progress}, queue_size=#{queue.size}")
        sleep wait_duration
      end

      queue.close
      threads.each(&:value) # wait for all threads
      each_result_queue&.close
      result_thread&.value

      @progress_bar&.finish

      results
    ensure
      threads&.each(&:kill)
    end

    # @param [#to_s] query
    # @param [Integer] start_time
    # @param [Integer] end_time
    # @return [Aws::CloudWatchLogs::Types::GetQueryResultsResponse]
    def fetch_one(query:, start_time:, end_time:)
      log(:debug, "starting query: #{start_time}..#{end_time}")

      query_id = aws_client.start_query(
        log_group_name: log_group_name,
        start_time:,
        end_time:,
        query_string: query.to_s,
      ).query_id

      wait_for_query_result(query_id)
    rescue Aws::CloudWatchLogs::Errors::InvalidParameterException => err
      if err.message.match?(/End time should not be before the service was generally available/)
        # rubocop:disable Layout/LineLength
        log(:warn, "query end_time=#{end_time} (#{Time.zone.at(end_time)}) is before Cloudwatch Insights availability, skipping")
        # rubocop:enable Layout/LineLength
        Aws::CloudWatchLogs::Types::GetQueryResultsResponse.new(results: [])
      else
        raise err
      end
    end

    def ensure_complete_logs?
      @ensure_complete_logs
    end

    def show_progress?
      !!@progress
    end

    # The prod events log ('prod_/srv/idp/shared/log/events.log') or equivalent in lower
    # environments
    def default_events_log
      env = Identity::Hostdata.in_datacenter? ? Identity::Hostdata.env : 'prod'
      "#{env}_/srv/idp/shared/log/events.log"
    end

    private

    def log(level, message)
      if logger
        int_level = Logger.const_get(level.upcase)
        if @progress_bar && int_level >= logger.level
          @progress_bar.log("#{level.upcase}: #{message}")
        else
          logger.add(int_level) { message }
        end
      end
    end

    # somehow sample responses returned 10,001 rows when we request 10,000
    # so we check for more than the limit
    def has_more_results?(size)
      size >= MAX_RESULTS_LIMIT
    end

    # Turns the key-value array from Cloudwatch into hashes
    # @param [Array<Array<Aws::CloudWatchLogs::Types::ResultField>>] results
    # @return [Array<Hash>]
    def parse_results(results)
      results.map do |row|
        row.map { |cell| [cell.field, cell.value] }.to_h.tap do |h|
          h.delete('@ptr') # just noise
        end
      end
    end

    # @return [Array<Range<Time>>]
    def slice_time_range(from:, to:, time_slices:)
      if (!from || !to) && !time_slices
        raise ArgumentError, 'either both :from and :to, or :time_slices must be provided'
      end

      if time_slices.present?
        time_slices
      elsif slice_interval
        slices = []
        low = from
        high = to
        while low < high
          slice_end = [low + slice_interval - 1, high].min
          slices << (low..slice_end)
          low += slice_interval
        end
        slices
      else
        [from..to]
      end
    end

    # @return [Integer]
    def midpoint(start_time:, end_time:)
      start_time.to_i + ((end_time.to_i - start_time.to_i) / 2)
    end

    # rubocop:disable Rails/TimeZone
    def wait_for_query_result(query_id)
      start = Time.now.to_f

      loop do
        log(:debug, "waiting on query_id=#{query_id}")
        sleep wait_duration
        response = aws_client.get_query_results(query_id: query_id)
        case response.status
        when 'Complete', 'Failed', 'Cancelled'
          duration = Time.now.to_f - start
          log(
            :debug,
            "finished query_id=#{query_id}, status=#{response.status}, duration=#{duration}",
          )
          return response
        else
          next
        end
      end
    end
    # rubocop:enable Rails/TimeZone

    def aws_client
      @aws_client ||= Aws::CloudWatchLogs::Client.new(region: 'us-west-2')
    end
  end
end
