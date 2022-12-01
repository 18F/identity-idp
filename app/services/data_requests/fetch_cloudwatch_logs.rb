module DataRequests
  # This class depends on the AWS cloudwatch SDK gem. That gem is only available
  # in development. The IDP role is not able to query cloudwatch logs. As a
  # result this code can only run in dev with a role that can query cloudwatch
  # logs
  class FetchCloudwatchLogs
    ResultRow = Struct.new(:timestamp, :message)

    attr_reader :uuid, :dates

    def initialize(uuid, dates)
      @uuid = uuid
      @dates = dates
    end

    def call
      raise "Only run #{self.class.name} locally" if Identity::Hostdata.in_datacenter?

      start_queries.flatten.uniq.sort_by(&:timestamp)
    end

    private

    def build_result_rows_from_aws_result(aws_results)
      aws_results.map do |aws_result|
        ResultRow.new(aws_result.first.value, aws_result.second.value)
      end
    end

    def cloudwatch_client
      require 'aws-sdk-cloudwatchlogs'
      @cloudwatch_client ||= Aws::CloudWatchLogs::Client.new region: 'us-west-2'
    end

    def query_string
      <<~QUERY
        fields @timestamp, @message
        | filter @message like /#{uuid}/
      QUERY
    end

    def start_queries
      results = Concurrent::Array.new
      errors = Concurrent::Array.new
      thread_pool = Concurrent::FixedThreadPool.new(1, fallback_policy: :abort)

      dates.each do |date|
        thread_pool.post do
          warn "Downloading logs for #{date}"
          results.push(wait_for_query_result(start_query(date)))
        rescue => e
          errors.push(e)
        end
      end

      thread_pool.shutdown
      thread_pool.wait_for_termination

      if errors.any?
        warn "#{errors.count} errors"
        raise errors.first
      end

      results
    end

    def start_query(date)
      query_start = (date - 12.hours).to_i
      query_end = (date + 36.hours).to_i

      cloudwatch_client.start_query(
        log_group_name: 'prod_/srv/idp/shared/log/events.log',
        start_time: query_start,
        end_time: query_end,
        query_string: query_string,
      ).query_id
    end

    def wait_for_query_result(query_id)
      loop do
        sleep 3
        response = cloudwatch_client.get_query_results(query_id: query_id)
        return build_result_rows_from_aws_result(response.results) if response.status == 'Complete'
      end
    end
  end
end
