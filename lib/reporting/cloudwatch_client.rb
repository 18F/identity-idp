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
      in_progress = Concurrent::Hash.new(0)

      thread_pool = Concurrent::FixedThreadPool.new(num_threads, fallback_policy: :abort)

      slice_time_range(from:, to:).tap do |ranges|
        logger.info("starting query, num_ranges=#{ranges.size} num_threads=#{num_threads}")
      end.each do |range|
        logger.info("enqueing range=#{range}")
        in_progress[range] += 1
        thread_pool.post { work_one(range:, thread_pool:, results:, orig_range: range) }
      end

      while (num_in_progress = in_progress.count { |_k, v| v > 0 }).positive?
        logger.info("waiting num_in_progress=#{num_in_progress}")
        sleep wait_duration
      end

      thread_pool.shutdown
      thread_pool.wait_for_termination

      results
    end

    # @api private
    def work_one(range:, thread_pool:, results:, orig_range:, in_progress:)
      start_time = range.begin.to_i
      end_time = range.end.to_i

      response = fetch_one(query:, start_time:, end_time:)

      logger.info("received results size=#{response.results.size}")

      if ensure_complete_logs? && max_size?(response.results.size)
        logger.info("exact limit reached, bisecting: start_time=#{start_time} end_time=#{end_time}")
        mid = midpoint(start_time:, end_time:)

        # -1 for the one that just finished, +2 for the two about to be enqueued
        in_progress[orig_range] += 1

        thread_pool.post do
          work_one(range: (start_time..mid), thread_pool:, results:, orig_range:, in_progress:)
        end
        thread_pool.post do
          work_one(range: (mid..end_time), thread_pool:, results:, orig_range:, in_progress:)
        end
      else
        in_progress[orig_range] -= 1
        results.concat(parse_results(response.results))
      end
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

    # somehow sample responses returned 10,001 rows when we request 10000
    def max_size?(size)
      size == Reporting::CloudwatchQuery::MAX_LIMIT ||
        size == (Reporting::CloudwatchQuery::MAX_LIMIT + 1)
    end

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
