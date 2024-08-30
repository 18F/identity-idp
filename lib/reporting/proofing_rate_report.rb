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
        subtitle: 'Detail',
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

      csv << ['Blanket Proofing Rate (IDV Started to Successfully Verified)', *reports.map(&:blanket_proofing_rate)]
      csv << ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', *reports.map(&:intent_proofing_rate)]
      csv << ['Actual Proofing Rate (Image Submitted to Successfully Verified)', *reports.map(&:actual_proofing_rate)]
      csv << ['Industry Proofing Rate (Verified minus IDV Rejected)', *reports.map(&:industry_proofing_rate)]

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
        reports = parallel? ? parallel_reports : single_threaded_reports

        reports.reduce([]) do |acc, report|
          if acc.empty?
            acc << report
          else
            acc << report.merge(acc.last)
          end
        end
      end
    end

    def single_threaded_reports
      Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
        trailing_days_subreports.each(&:data)
      end
    end

    def parallel_reports
      threads = trailing_days_subreports.map do |report|
        Thread.new do
          report.tap(&:data)
        end.tap do |thread|
          thread.report_on_exception = false
        end
      end

      Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
        threads.map(&:value)
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

    def trailing_days_subreports
      [0, *DATE_INTERVALS].each_cons(2).map do |slice_end, slice_start|
        time_range = if slice_end.zero?
                       Range.new(
                         (end_date - slice_start.days).beginning_of_day,
                         (end_date - slice_end.days).end_of_day,
                       )
                     else
                       Range.new(
                         (end_date - slice_start.days).beginning_of_day,
                         (end_date - slice_end.days).end_of_day - 1.day,
                       )
                     end
        Reporting::IdentityVerificationReport.new(
          issuers: nil, # all issuers
          time_range: time_range,
          cloudwatch_client: cloudwatch_client,
        )
      end
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
    parallel: parallel,
    verbose: verbose,
  ).to_csv
end
# rubocop:enable Rails/Output
