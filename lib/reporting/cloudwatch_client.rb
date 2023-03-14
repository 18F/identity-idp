module Reporting
  class CloudwatchClient
    DEFAULT_NUM_THREADS = 5
    DEFAULT_WAIT_DURATION = 3

    attr_reader :num_threads, :wait_duration, :slice_interval, :logger

    # @param [Boolean] ensure_complete_logs when true, will detect when queries return exactly
    #  10,000 rows (Cloudwatch Insights max limit) and then recursively split the query window into
    #  two queries until we're certain we've queried all rows
    # @param [ActiveSupport::Duration] slice_interval starting interval to split up and query across
    def initialize(
      ensure_complete_logs: true,
      num_threads: DEFAULT_NUM_THREADS,
      wait_duration: DEFAULT_WAIT_DURATION,
      slice_interval: 1.day,
      logger: Logger.new(STDERR)
    )
      @ensure_complete_logs = ensure_complete_logs
      @num_threads = num_threads
      @wait_duration = wait_duration
      @slice_interval = slice_interval
      @logger = logger
    end

    # @param [Reporting::CloudwatchQuery] query
    # @param [Time] from
    # @param [Time] to
    # @return [Array<Array<Types::ResultField>>]
    def fetch(query:, from:, to:)
      results = Concurrent::Array.new
      queue = Queue.new

      slice_time_range(from:, to:).map do |range|
        queue << range
      end

      logger.info("starting query, queue_size=#{queue.length} num_threads=#{num_threads}")

      threads = num_threads.times.map do |thread_idx|
        Thread.new do
          while (range = queue.pop)
            start_time = range.begin.to_i
            end_time = range.end.to_i

            response = fetch_one(query:, start_time:, end_time:)

            if ensure_complete_logs? && response.results.size == Reporting::CloudwatchQuery::MAX_LIMIT
              logger.info("exact limit reached, bisecting: start_time=#{start_time} end_time=#{end_time}")
              mid = midpoint(start_time:, end_time:)
              queue << (start_time..mid)
              queue << (mid..end_time)
            else
              results.concat(parse_results(response.results))
            end
          end

          logger.info("thread done thread_idx=#{thread_idx}")

          nil
        end
      end

      until queue.empty?
        sleep wait_duration
      end
      queue.close
      threads.map(&:value) # wait for all threads

      results
    end

    # @param [Reporting::CloudwatchQuery] query
    # @param [Integer] start_time
    # @param [Integer] end_time
    # @return [Aws::CloudWatchLogs::Types::GetQueryResultsResponse]
    def fetch_one(query:, start_time:, end_time:)
      logger.info("starting query: #{start_time}..#{end_time}")

      query_id = cloudwatch_client.start_query(
        log_group_name: 'prod_/srv/idp/shared/log/events.log',
        start_time:,
        end_time:,
        query_string: query.to_query,
      ).query_id

      wait_for_query_result(query_id)
    end

    def ensure_complete_logs?
      @ensure_complete_logs
    end

    private

    # Pulls out and parses the "@message" field as JSON
    # @param [Array<Array<Types::ResultField>>] results
    # @return [Array<Hash>]
    def parse_results(results)
      results.map do |result_fields|
        json_str = result_fields.find { |result_field| result_field.field == '@message' }.value
        JSON.parse(json_str)
      end
    end

    # @return [Array<Range<Time>>]
    def slice_time_range(from:, to:)
      slices = []
      low = from
      high = to
      while low < high
        slice_end = [low + slice_interval, high].min
        slices << (low..slice_end)
        low += slice_interval
      end
      slices
    end

    # @return [Integer]
    def midpoint(start_time:, end_time:)
      start_time.to_i + ((end_time.to_i - start_time.to_i) / 2)
    end

    def wait_for_query_result(query_id)
      start = Time.now.to_f

      loop do
        logger.info("waiting on query_id=#{query_id}")
        sleep wait_duration
        response = cloudwatch_client.get_query_results(query_id: query_id)
        case response.status
        when 'Complete', 'Failed', 'Cancelled'
          duration = Time.now.to_f - start
          logger.info("finished query_id=#{query_id}, status=#{response.status}, duration=#{duration}")
          return response
        else
          next
        end
      end
    end

    def cloudwatch_client
      require 'aws-sdk-cloudwatchlogs'
      @cloudwatch_client ||= Aws::CloudWatchLogs::Client.new(region: 'us-west-2')
    end
  end
end
