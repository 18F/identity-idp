# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'
require 'reporting/unknown_progress_bar'

module Reporting
  class ProofingRateReport
    DATE_INTERVALS = [30, 60, 90].freeze

    attr_reader :end_date, :wait_duration

    def initialize(
      end_date:,
      verbose: false,
      progress: false,
      wait_duration: CloudwatchClient::DEFAULT_WAIT_DURATION,
      parallel: false
    )
      @end_date = end_date.in_time_zone('UTC')
      @verbose = verbose
      @progress = progress
      @wait_duration = wait_duration
      @parallel = parallel
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    def parallel?
      @parallel
    end

    def proofing_rate_emailable_report
      EmailableReport.new(
        title: 'Proofing Rate Metrics',
        float_as_percent: true,
        precision: 2,
        table: as_csv,
        filename: 'proofing_rate_metrics',
      )
    end

    # rubocop:disable Layout/LineLength
    def as_csv
      csv = []

      csv << ['Metric', *DATE_INTERVALS.map { |days| "Trailing #{days}d" }]

      csv << ['Start Date', *reports.map(&:time_range).map(&:begin).map(&:to_date)]
      csv << ['End Date', *reports.map(&:time_range).map(&:end).map(&:to_date)]

      csv << ['IDV Started', *reports.map(&:idv_started)]
      csv << ['Welcome Submitted', *reports.map(&:idv_doc_auth_welcome_submitted)]
      csv << ['Image Submitted', *reports.map(&:idv_doc_auth_image_vendor_submitted)]
      csv << ['Successfully Verified', *reports.map(&:successfully_verified_users)]
      csv << ['IDV Rejected (Non-Fraud)', *reports.map(&:idv_doc_auth_rejected)]
      csv << ['IDV Rejected (Fraud)', *reports.map(&:idv_fraud_rejected)]

      csv << ['Blanket Proofing Rate (IDV Started to Successfully Verified)', *blanket_proofing_rates(reports)]
      csv << ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', *intent_proofing_rates(reports)]
      csv << ['Actual Proofing Rate (Image Submitted to Successfully Verified)', *actual_proofing_rates(reports)]
      csv << ['Industry Proofing Rate (Verified minus IDV Rejected)', *industry_proofing_rates(reports)]

      csv
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end
    # rubocop:enable Layout/LineLength

    def to_csv
      CSV.generate do |csv|
        as_csv.each do |row|
          csv << row
        end
      end
    end

    def reports
      @reports ||= begin
        sub_reports = [0, *DATE_INTERVALS].each_cons(2).map do |slice_end, slice_start|
          Reporting::IdentityVerificationReport.new(
            issuers: nil, # all issuers
            time_range: Range.new(
              (end_date - slice_start.days).beginning_of_day,
              (end_date - slice_end.days).beginning_of_day,
            ),
            cloudwatch_client: cloudwatch_client,
          )
        end

        reports = if parallel?
                    threads = sub_reports.map do |report|
                      Thread.new do
                        report.tap(&:data)
                      end.tap do |thread|
                        thread.report_on_exception = false
                      end
                    end

                    Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
                      threads.map(&:value)
                    end
                  else
                    Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
                      sub_reports.each(&:data)
                    end
                  end

        reports.reduce([]) do |acc, report|
          if acc.empty?
            acc << report
          else
            acc << report.merge(acc.last)
          end
        end
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def blanket_proofing_rates(reports)
      reports.map do |report|
        report.blanket_proofing_rates
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def intent_proofing_rates(reports)
      reports.map do |report|
        report.intent_proofing_rates
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def actual_proofing_rates(reports)
      reports.map do |report|
        report.actual_proofing_rates
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def industry_proofing_rates(reports)
      reports.map do |report|
        report.industry_proofing_rates
      end
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        ensure_complete_logs: true,
        progress: false,
        logger: verbose? ? Logger.new(STDERR) : nil,
        wait_duration: wait_duration,
      )
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  end_date = if ARGV.first.match?(/\d{4}-\d{1,2}-\d{1,2}/)
               Date.parse(ARGV.first)
             else
               ActiveSupport::TimeZone['UTC'].today
             end
  progress = !ARGV.include?('--no-progress')
  verbose = ARGV.include?('--verbose')
  parallel = !ARGV.include?('--no-parallel')

  puts Reporting::ProofingRateReport.new(
    end_date: end_date,
    progress: progress,
    verbose: verbose,
    parallel: parallel,
  ).to_csv
end
# rubocop:enable Rails/Output
