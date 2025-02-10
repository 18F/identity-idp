# frozen_string_literal: true

require 'reporting/protocols_report'

module Reports
  class ProtocolsReport < BaseReport
    REPORT_NAME = 'protocols-report'

    attr_accessor :report_date

    def perform(date = Time.zone.yesterday.end_of_day)
      return unless IdentityConfig.store.s3_reports_enabled

      @report_date = date
      message = "Report: #{REPORT_NAME} #{report_date}"
      subject = "Weekly Protocols Report - #{report_date}"

      report_configs.each do |report_hash|
        reports = weekly_protocols_emailable_reports

        report_hash['emails'].each do |email|
          ReportMailer.tables_report(
            email:,
            subject:,
            message:,
            reports:,
            attachment_format: :csv,
          ).deliver_now
        end
      end
    end

    private

    def weekly_protocols_emailable_reports
      report.as_emailable_reports
    end

    def report
      @report ||= Reporting::ProtocolsReport.new(
        issuers: nil,
        time_range: report_date.all_week,
      )
    end

    def report_configs
      IdentityConfig.store.protocols_report_config
    end
  end
end
