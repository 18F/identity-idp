require 'reporting/identity_verification_report'

module Reports
  class IdentityVerificationReport < BaseReport
    REPORT_NAME = 'identity-verification-report'.freeze

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled
      self.report_date = report_date

      csv = report_maker.to_csv

      save_report(REPORT_NAME, csv, extension: 'csv')

      if emails.empty?
        Rails.logger.warn 'No email addresses received - Identity Verification Report NOT SENT'
        return false
      end

      emails.each do |email|
        ReportMailer.tables_report(
          email: email,
          subject: "Daily Identity Verification Report - #{report_date.to_date}",
          reports: reports,
          message: preamble,
          attachment_format: :csv,
        ).deliver_now
      end
    end

    def preamble
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <h2>
          Identity Verification Report
        </h2>
        <p>
          Disclaimer: This Report is In Progress: Not Production Ready
        </p>
      HTML
    end

    def emails
      [IdentityConfig.store.team_ada_email]
    end

    def reports
      [report_maker.identity_verification_emailable_report]
    end

    def report_maker
      Reporting::IdentityVerificationReport.new(
        issuers: [],
        time_range: report_date.all_day,
        slice: 4.hours,
      )
    end
  end
end
