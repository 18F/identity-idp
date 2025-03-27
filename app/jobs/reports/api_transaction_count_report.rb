# frozen_string_literal: true

require 'identity/hostdata'
require 'csv'

module Reports
  class ApiTransactionCountReportJob < BaseReport
    REPORT_NAME = 'api-transaction-count-report'

    def perform(report_date = Time.zone.today)
      Rails.logger.info("Starting #{REPORT_NAME} for #{report_date}")

      # Generate the report
      report = Reporting::ApiTransactionCountReport.new(report_date)

      # Generate the emailable report
      emailable_report = report.api_transaction_emailable_report

      # Send the report via email
      send_report_email(emailable_report, report_date)

      Rails.logger.info("#{REPORT_NAME} completed successfully for #{report_date}")
    rescue => e
      Rails.logger.error("#{REPORT_NAME} failed: #{e.message}")
      raise
    end

    private

    def send_report_email(emailable_report, report_date)
      email_addresses = emails.compact_blank
      if email_addresses.empty?
        Rails.logger.warn "#{self.class::REPORT_NAME} NOT SENT - No email addresses provided"
        return false
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "#{REPORT_NAME.humanize} - #{report_date}",
        reports: [emailable_report],
        message: "Please find attached the #{REPORT_NAME.humanize} for #{report_date}.",
        attachment_format: :csv,
      ).deliver_now
    end
  end
end
