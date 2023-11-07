require 'reporting/cloudwatch_client'

module DataRequests
  module Local
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

      # @return [Array<Range<Time>>]
      def query_ranges
        ranges = []

        # Converts a set of consecutive dates into a Range
        # @param [Array<Date>] run
        # @return [Array<Range<Time>>]
        run_to_range = ->(run) do
          # break up runs by week so that queries stay a reasonable size
          if run.size > 7
            first, *mid, last = run.each_slice(7).map do |slice|
              slice.first.beginning_of_day..slice.last.end_of_day
            end

            [(first.begin - 12.hours)..first.end, *mid, last.begin..(last.end + 12.hours)]
          else
            (run.first.beginning_of_day - 12.hours)..(run.last.end_of_day + 12.hours)
          end
        end

        current_run = []

        [*dates, nil].each_cons(2).each do |first, second|
          current_run << first

          if !second || first + 1 == second
            next
          else
            ranges << run_to_range[current_run]

            current_run = []
          end
        end

        ranges << run_to_range[current_run]

        ranges.flatten
      end

      private

      def cloudwatch_client
        @cloudwatch_client ||= Reporting::CloudwatchClient.new(
          ensure_complete_logs: true,
          slice_interval: false,
          logger:,
          **cloudwatch_client_options,
        )
      end

      def query_string
        <<~QUERY
          fields @timestamp, @message
          | filter properties.user_id = '#{uuid}' and name != 'IRS Attempt API: Event metadata'
        QUERY
      end

      def logger
        @logger ||= Logger.new(STDERR, level: :warn)
      end

      def start_queries
        cloudwatch_client.fetch(
          time_slices: query_ranges,
          query: query_string,
        )
      end
    end
  end
end
