# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'
require 'reporting/unknown_progress_bar'

module Reporting
  class MonthlyIdvReport
    attr_reader :end_date

    def initialize(end_date:, verbose: false, progress: false, parallel: false)
      @end_date = end_date.in_time_zone('UTC')
      @verbose = verbose
      @progress = progress
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

    def monthly_idv_report_emailable_report
      EmailableReport.new(
        title: 'Proofing Rate Metrics',
        subtitle: 'Condensed (NEW)',
        float_as_percent: true,
        precision: 2,
        table: as_csv,
        filename: 'condensed_idv',
      )
    end

    def as_csv
      csv = []

      csv << ['Metric', *reports.map { |t| t.time_range.begin.strftime('%b %Y') }]
      csv << ['IDV started', *reports.map(&:idv_started)]

      csv << ['# of successfully verified users', *reports.map(&:successfully_verified_users)]
      csv << ['% IDV started to successfully verified', *reports.map(&:blanket_proofing_rate)]

      csv << ['# of workflow completed', *reports.map(&:idv_final_resolution)]
      csv << ['% rate of workflow completed', *reports.map(&:idv_final_resolution_rate)]

      csv << ['# of users verified (total)', *reports.map(&:verified_user_count)]
    rescue Aws::CloudWatchLogs::Errors::ThrottlingException => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
      ]
    end

    def reports
      @reports ||= begin
        parallel? ? parallel_reports : non_parallel_reports
      end
    end

    def non_parallel_reports
      Reporting::UnknownProgressBar.wrap(show_bar: progress?) do
        monthly_subreports.each(&:data)
      end
    end

    def parallel_reports
      threads = monthly_subreports.map do |report|
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

    def monthly_subreports
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

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        ensure_complete_logs: true,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end
  end
end
