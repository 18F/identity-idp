module Reporting
  class CloudwatchClient
    NUM_THREADS = 5
    WAIT_DURATION = 3

    # @param [Reporting::CloudwatchQuery] query
    # @param [Time] from
    # @param [Time] to
    # @return [Array<Array<Types::ResultField>>]
    def fetch(query:, from:, to:)
      results = Concurrent::Array.new
      errors = Concurrent::Array.new
      queue = Queue.new

      slice_days(from:, to:).map do |range|
        queue << range
      end

      logger.info("starting query, queue_size=#{queue.length} num_threads=#{NUM_THREADS}")

      threads = NUM_THREADS.times.map do |thread_idx|
        Thread.new do
          while (range = queue.pop)
            start_time = range.begin.to_i
            end_time = range.end.to_i

            response = fetch_one(query:, start_time:, end_time:)

            if response.results.size == Reporting::CloudwatchQuery::MAX_LIMIT
              mid = midpoint(start_time:, end_time:)
              queue << start_time..mid
              queue << mid..end_time
            else
              results.concat(response.results)
            end
          end

          logger.info("thread done thread_idx=#{thread_idx}")

          nil
        end
      end

      until queue.empty?
        sleep WAIT_DURATION
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

    def logger
      @logger = Logger.new(STDERR)
    end

    private

    # @return [Array<Range<Time>>]
    def slice_days(from:, to:)
      slices = []
      low = from
      high = to
      while low < high
        slice_end = [low + 1.day, high].min
        slices << (low..slice_end)
        low += 1.day
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
        sleep WAIT_DURATION
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
