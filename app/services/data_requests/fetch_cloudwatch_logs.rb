require 'reporting/cloudwatch_client'

module DataRequests
  # This class depends on the AWS cloudwatch SDK gem. That gem is only available
  # in development. The IDP role is not able to query cloudwatch logs. As a
  # result this code can only run in dev with a role that can query cloudwatch
  # logs
  class FetchCloudwatchLogs
    ResultRow = Struct.new(:timestamp, :message)

    attr_reader :uuid, :dates, :cloudwatch_client_options

    def initialize(uuid, dates, cloudwatch_client_options: {})
      @uuid = uuid
      @dates = dates
      @cloudwatch_client_options = cloudwatch_client_options
    end

    def call
      raise "Only run #{self.class.name} locally" if Identity::Hostdata.in_datacenter?

      start_queries.map do |row|
        ResultRow.new(row['@timestamp'], row['@message'])
      end.uniq.sort_by(&:timestamp)
    end

    private

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        ensure_complete_logs: true,
        slice: query_ranges,
        logger: logger,
        **cloudwatch_client_options,
      )
    end

    def query_string
      <<~QUERY
        fields @timestamp, @message
        | filter @message like /#{uuid}/
      QUERY
    end

    def query_ranges
      dates.map do |date|
        in_utc = date.in_time_zone('UTC')
        in_utc.beginning_of_day..in_utc.end_of_day
      end
    end

    def logger
      @logger ||= Logger.new(STDERR, level: :warn)
    end

    def start_queries
      cloudwatch_client.fetch(
        # NOTE :from and :to are just placeholders here since we passed :slice to the constructor
        # Maybe we can redo the options to only need one of them?
        from: dates.min,
        to: dates.max,
        query: query_string,
      )
    end
  end
end
