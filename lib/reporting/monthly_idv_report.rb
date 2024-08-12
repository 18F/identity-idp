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
  # MW: This might make more sense as part of IdentityVerificationReport.
  # Right now I'm optimizing for working code; it's easy to move.
  # Also this might not even be the right name?
  class MonthlyIdvReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :end_date, :first_month, :second_month, :third_month

    def initialize(end_date:)
      @end_date = end_date.in_time_zone('UTC')
    end

    def monthly_idv_report_emailable_report
      EmailableReport.new(
        title: 'Proofing Rate Metrics',
        subtitle: 'Condensed (NEW)',
        float_as_percent: true,
        precision: 2,
        table: as_csv,
        filename: 'condensed_hop_results', # FIXME, ask May
      )
    end

    def as_csv
      puts "... found #{reports.count} reports"
      puts "!! #{reports.inspect}"
      csv = []

      csv << ['Timeframe/month', *reports.map {|t| t.time_range.begin.strftime('%b %Y') }]
      csv << ['IDV started', *reports.map(&:idv_started)]

      csv << ['# of successfully verified users', *reports.map(&:successfully_verified_users)]
      # successfully_verified / idv_started, "blanked_proofing_rates"
      csv << ['% rate of successfully verified users', *reports.map(&:blanket_proofing_rates)]

      csv << ['# of workflow completed', *reports.map(&:idv_final_resolution)]
      csv << ['% rate of workflow completed', *reports.map(&:idv_final_resolution_rate)]
    end

    def reports
      @reports ||= Reporting::ProofingRateReport.new(
        end_date: end_date,
        parallel: false,
        by_month: true,
      ).reports
    end
  end
end
