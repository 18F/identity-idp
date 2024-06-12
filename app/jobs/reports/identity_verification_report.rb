# frozen_string_literal: true

require 'reporting/identity_verification_report'

module Reports
  class IdentityVerificationReport < BaseReport
    REPORT_NAME = 'identity-verification-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled
      self.report_date = report_date

      csv = report_maker.to_csv

      save_report(REPORT_NAME, csv, extension: 'csv')

      email = IdentityConfig.store.team_ada_email
      if email.blank?
        Rails.logger.warn 'No email addresses received - Identity Verification Report NOT SENT'
        return false
      end

      ReportMailer.tables_report(
        email: email,
        subject: "Daily Identity Verification Report - #{report_date.to_date}",
        reports: reports,
        message: message,
        attachment_format: :xlsx,
      ).deliver_now
    end

    def message
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        #{preamble}

        <a href="https://docs.google.com/document/d/1fERPx-8ryeO84xo32Ky0em8aHbQW_VzJvThhpgfkSYc/edit?usp=sharing">
          Identity Verification Metrics Definitions
        </a>
      HTML
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
