# frozen_string_literal: true

require 'reporting/authentication_report'

module Reports
  class AuthenticationReport < BaseReport
    REPORT_NAME = 'authentication-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled

      self.report_date = report_date
      message = "Report: #{REPORT_NAME} #{report_date}"
      subject = "Weekly Authentication Report - #{report_date}"

      report_configs.each do |report_hash|
        reports = weekly_authentication_emailable_reports(report_hash['issuers'])

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

    def weekly_authentication_emailable_reports(issuers)
      Reporting::AuthenticationReport.new(
        issuers:,
        time_range: report_date.all_week,
      ).as_emailable_reports
    end

    def report_configs
      IdentityConfig.store.weekly_auth_funnel_report_config
    end
  end
end
