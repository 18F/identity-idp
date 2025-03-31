# frozen_string_literal: true

require 'reporting/api_transaction_count_report'

module Reports
  class APITransactionCountReportJob < BaseReport
    REPORT_NAME = 'api-transaction-count-report'

    attr_accessor :report_date

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - Monthly Key Metrics Report NOT SENT'
        return false
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "API Transaction Count Reports - #{date.to_date}",
        message: "API Transaction Count Report - #{date.to_date}.",
        reports:,
        attachment_format: :csv,
      ).deliver_now
    end

    private

    def emails
      emails = [*IdentityConfig.store.team_daily_reports_emails]
      if report_date.next_day.day == 1
        emails += IdentityConfig.store.team_all_login_emails
      end
      emails
    end

    def api_transaction_emailable_reports(issuers)
      Reporting::APITransactionCountReport.new(
        time_range: report_date.all_month,
      ).to_csvs.map do |csv|
        { title: 'API Transaction Count Report', table: CSV.parse(csv) }
      end
    end

    def report_configs
      IdentityConfig.store.api_transaction_count_report_config
    end
  end
end
