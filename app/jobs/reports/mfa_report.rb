# frozen_string_literal: true

require 'reporting/mfa_report'

module Reports
  class MfaReport < BaseReport
    REPORT_NAME = 'mfa-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled

      self.report_date = report_date
      message = "Report: #{REPORT_NAME} #{report_date}"
      subject = "Monthly MFA Report - #{report_date}"

      report_configs.each do |report_hash|
        reports = monthly_mfa_emailable_reports(report_hash['issuers'])

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

    def monthly_mfa_emailable_reports(issuers)
      Reporting::MfaReport.new(
        issuers:,
        time_range: report_date.all_month,
      ).as_emailable_reports
    end

    def report_configs
      IdentityConfig.store.mfa_report_config
    end
  end
end
