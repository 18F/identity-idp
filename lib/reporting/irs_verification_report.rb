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
  class IrsVerificationReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    VERIFICATION_DEMAND = 'IdV: doc auth welcome visited'
    DOCUMENT_AUTHENTICATION_SUCCESS = 'IdV: doc auth ssn visited'
    INFORMATION_VALIDATION_SUCCESS = 'IdV: phone of record visited'
    PHONE_VERIFICATION_SUCCESS = 'idv_enter_password_visited'
    TOTAL_VERIFIED = 'User registration: complete'

    # @param [Array<String>] issuers
    # @param [Range<Time>] time_range
    def initialize(time_range:, issuers:)
      @issuers = issuers
      @time_range = time_range || previous_week_range
    end

    def as_tables
      [
        overview_table,
        funnel_table,
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: data_definition_table,
          filename: 'Definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: overview_table,
          filename: 'Overview Report',
        ),
        Reporting::EmailableReport.new(
          title: 'Funnel Metrics',
          subtitle: '',
          float_as_percent: true,
          precision: 2,
          table: funnel_table,
          filename: 'Funnel Metrics',
        ),
      ]
    end

    def to_csvs
      as_emailable_reports.map do |report|
        CSV.generate do |csv|
          report.table.each { |row| csv << row }
        end
      end
    end

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin.to_date} to #{time_range.end.to_date}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuers.join(', ')],
      ]
    end

    def funnel_table
      [
        [
          'Metric',
          'Count',
          'Rate',

        ],
        [
          'Verfication Demand',
          verification_demand_results,
          to_percent(verification_demand_results, verification_demand_results),
        ],
        [
          'Document Authentication Success',
          document_authentication_success_results,
          to_percent(document_authentication_success_results, verification_demand_results),
        ],
        [
          'Information Verification Success',
          information_validation_success_results,
          to_percent(information_validation_success_results, verification_demand_results),
        ],
        [
          'Phone Verification Success',
          phone_verification_success_results,
          to_percent(phone_verification_success_results, verification_demand_results),
        ],
        [
          'Total Verified Success',
          total_verified_results,
          to_percent(total_verified_results, verification_demand_results),
        ],
        [
          'Verification Fallouts',
          verification_demand_results - total_verified_results,
          to_percent(
            verification_demand_results - total_verified_results,
            verification_demand_results,
          ),
        ],
      ]
    end

    def data_definition_table
      [
        ['Metric', 'Definition'],
        ['Verification Demand', 'The count of users who started the identity verification process'],
        ['Document Authentication Success',
         'Users who successfully completed document authentication'],
        ['Information Validation Success', 'Users who successfully validated their information'],
        ['Phone Verification Success', 'Users who successfully verified their using their phone'],
        ['Total Verified', 'Users who completed the entire process'],
        ['Verification Fallouts',
         'The percentage of users that did not complete the identity verification process'],
      ]
    end

    private

    def previous_week_range
      today = Time.zone.today
      last_sunday = today.beginning_of_week(:sunday) - 7.days
      last_saturday = last_sunday + 6.days

      last_sunday.to_date..last_saturday.to_date
    end

    def fetch_results(query:)
      Rails.logger.info("Executing query: #{query}")
      Rails.logger.info("Time range: #{time_range.begin.to_time} to #{time_range.end.to_time}")

      # results = cloudwatch_client.fetch(
      #   query:,
      #   from: time_range.begin.to_date,
      #   to: time_range.end.to_date,
      # )

      results = cloudwatch_client.fetch(
        query:,
        from: time_range.begin.beginning_of_day,
        to: time_range.end.end_of_day,
      )

      Rails.logger.info("Results: #{results.inspect}")
      results
    rescue StandardError => e
      Rails.logger.error("Failed to fetch results for query: #{e.message}")
      []
    end

    def column_labels(row)
      row&.keys || []
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        progress: false,
        ensure_complete_logs: false,
      )
    end

    def verification_demand_results
      fetch_results(query: query(event: VERIFICATION_DEMAND)).count
    end

    def document_authentication_success_results
      fetch_results(query: query(event: DOCUMENT_AUTHENTICATION_SUCCESS)).count
    end

    def information_validation_success_results
      fetch_results(query: query(event: INFORMATION_VALIDATION_SUCCESS)).count
    end

    def phone_verification_success_results
      fetch_results(query: query(event: PHONE_VERIFICATION_SUCCESS)).count
    end

    def total_verified_results
      fetch_results(query: query(event: TOTAL_VERIFIED)).count
    end

    def to_percent(numerator, denominator)
      (100.0 * numerator / denominator).round(2)
    end

    def query(event)
      params = {
        issuers: quote(issuers.inspect),
        event: quote([event.inspect]),
      }
      format(<<~QUERY, params)
         filter name IN %{event}
        | fields @message
        | filter properties.sp_request.facial_match
        | filter properties.service_provider IN %{issuers}
      QUERY
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  # Parse command-line options
  options = Reporting::CommandLineOptions.new.parse!(ARGV)
  # Generate the report and output CSVs
  Reporting::IrsVerificationReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
