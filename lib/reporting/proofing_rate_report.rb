# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'
require 'reporting/unknown_progress_bar'

module Reporting
  class ProofingRateReport
    DATE_INTERVALS = [30, 60, 90].freeze

    attr_reader :end_date, :wait_duration, :by_month

    def initialize(
      end_date:,
      verbose: false,
      progress: false,
      wait_duration: CloudwatchClient::DEFAULT_WAIT_DURATION,
      parallel: false,
      by_month: false
    )
      @end_date = end_date.in_time_zone('UTC')
      @verbose = verbose
      @progress = progress
      @wait_duration = wait_duration
      @parallel = false # remove me, 50/50 state risk?
      @by_month = by_month
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
      @by_month = false
      @reports = nil
      csv = []

      csv << ['Metric', *DATE_INTERVALS.map { |days| "Trailing #{days}d" }]

      csv << ['Start Date', *reduced_reports.map(&:time_range).map(&:begin).map(&:to_date)]
      csv << ['End Date', *reduced_reports.map(&:time_range).map(&:end).map(&:to_date)]

      csv << ['IDV Started', *reduced_reports.map(&:idv_started)]
      csv << ['Welcome Submitted', *reduced_reports.map(&:idv_doc_auth_welcome_submitted)]
      csv << ['Image Submitted', *reduced_reports.map(&:idv_doc_auth_image_vendor_submitted)]
      csv << ['Successfully Verified', *reduced_reports.map(&:successfully_verified_users)]
      csv << ['IDV Rejected (Non-Fraud)', *reduced_reports.map(&:idv_doc_auth_rejected)]
      csv << ['IDV Rejected (Fraud)', *reduced_reports.map(&:idv_fraud_rejected)]

      csv << ['Blanket Proofing Rate (IDV Started to Successfully Verified)', *reduced_reports.map(&:blanket_proofing_rates)]
      csv << ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', *reduced_reports.map(&:intent_proofing_rates)]
      csv << ['Actual Proofing Rate (Image Submitted to Successfully Verified)', *reduced_reports.map(&:actual_proofing_rates)]
      csv << ['Industry Proofing Rate (Verified minus IDV Rejected)', *reduced_reports.map(&:industry_proofing_rates)]

      csv
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end
    # rubocop:enable Layout/LineLength

    def monthly_idv_report_emailable_report
      EmailableReport.new(
        title: 'Proofing Rate Metrics',
        subtitle: 'Condensed (NEW)',
        float_as_percent: true,
        precision: 2,
        table: divr_as_csv,
        filename: 'condensed_hop_results', # FIXME, ask May
      )
    end

    # Should I cargo cult in the ThrottlingException from above? Can we extract that?
    def divr_as_csv
      @by_month = true # tsk tsk
      @reports = nil
      csv = []

      csv << ['Metric', *reports.map { |t| t.time_range.begin.strftime('%b %Y') }]
      csv << ['IDV started', *reports.map(&:idv_started)]

      csv << ['# of successfully verified users', *reports.map(&:successfully_verified_users)]
      csv << ['% IDV started to successfully verified', *reports.map(&:blanket_proofing_rates)]

      csv << ['# of workflow completed', *reports.map(&:idv_final_resolution)]
      csv << ['% rate of workflow completed', *reports.map(&:idv_final_resolution_rate)]

      csv << ['# of users verified (total)', *reports.map(&:verified_user_count)]
    end

    def to_csv
      CSV.generate do |csv|
        as_csv.each do |row|
          csv << row
        end
      end
    end

    def sub_reports
      by_month ? by_month_ranges : trailing_days_ranges
    end

    def reports
      @reports ||= begin
        Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
          sub_reports.each(&:data)
        end
      end
    end

    def reduced_reports
      reports.reduce([]) do |acc, report|
        if acc.empty?
          acc << report
        else
          acc << report.merge(acc.last)
        end
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

    def trailing_days_ranges
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

    def by_month_ranges
      ranges = [
        (end_date - 2.months).all_month,
        (end_date - 1.month).all_month,
        end_date.all_month,
      ]

      ranges.map do |range|
        Reporting::IdentityVerificationReport.new(
          issuers: nil, # all issuers
          time_range: range,
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

  puts Reporting::ProofingRateReport.new(
    end_date: end_date,
    progress: progress,
    verbose: verbose,
  ).to_csv
end
# rubocop:enable Rails/Output
