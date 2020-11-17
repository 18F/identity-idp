require 'aws-sdk-cloudwatchlogs'

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
      raise "Only run #{self.class.name} locally" if LoginGov::Hostdata.in_datacenter?

      query_ids = start_queries
      wait_for_query_results(query_ids).flatten.uniq.sort_by(&:timestamp)
    end

    private

    def build_result_rows_from_aws_result(aws_results)
      aws_results.map do |aws_result|
        ResultRow.new(aws_result.first.value, aws_result.second.value)
      end
    end

    def cloudwatch_client
      @cloudwatch_client ||= Aws::CloudWatchLogs::Client.new
    end

    def query_string
      <<~QUERY
        fields @timestamp, @message
        | filter @message like /#{uuid}/
      QUERY
    end

    def start_queries
      dates.map do |date|
        warn "Downloading logs for #{date}"
        query_start = (date - 12.hours).to_i
        query_end = (date + 36.hours).to_i

        cloudwatch_client.start_query(
          log_group_name: 'prod_/srv/idp/shared/log/events.log',
          start_time: query_start,
          end_time: query_end,
          query_string: query_string,
        ).query_id
      end
    end

    def wait_for_query_results(query_ids)
      results = []

      query_ids.map do |query_id|
        Thread.new do
          results.push(wait_for_query_result(query_id))
        end
      end.each(&:join)

      results
    end

    def wait_for_query_result(query_id)
      sleep 3
      response = cloudwatch_client.get_query_results(query_id: query_id)
      if response.status == 'Complete'
        aws_results = response.results
        return build_result_rows_from_aws_result(aws_results)
      end
      wait_for_query_result(query_id)
    end
  end
end
