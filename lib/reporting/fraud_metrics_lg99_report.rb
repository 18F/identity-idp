# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class FraudMetricsLg99Report
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      IDV_PLEASE_CALL_VISITED = 'IdV: Verify please call visited'
      IDV_SETUP_ERROR_VISITED = 'IdV: Verify setup errors visited'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def as_emailable_reports
      Reporting::EmailableReport.new(
        title: 'LG-99 Metrics',
        table: lg99_metrics_table,
        filename: 'lg99_metrics',
      )
    end

    def lg99_metrics_table
      [
        ['Metric', 'Total'],
        ['Unique users seeing LG-99', totals('unique_users_count')],
      ]
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end

    def to_csv
      CSV.generate do |csv|
        lg99_metrics_table.each do |row|
          csv << row
        end
      end
    end

    # @return Array<Hash>
    def data
      @data ||= begin
        fetch_results
      end
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        event_names: quote(Events.all_events),
      }

      format(<<~QUERY, params)
        fields
            name
          , @timestamp
          , properties.user_id as user_id,
          , properties.new_event AS new_event
        | filter properties.new_event = 1
        | filter name in %{event_names}
        | stats count_distinct(user_id) as unique_users_count
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    def totals(key)
      data.inject(0) { |sum, slice| slice[key].to_i + sum }
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  Reporting::FraudMetricsLg99Report.new(**options).to_csv.each do |csv|
    puts csv
  end
end
# rubocop:enable Rails/Output
