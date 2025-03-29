# frozen_string_literal: true

require 'reporting/api_transaction_count_report'

module Reports
  class APITransactionCountReportJob < BaseReport
    REPORT_NAME = 'api-transaction-count-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled

      self.report_date = report_date
      message = "Report: #{REPORT_NAME} #{report_date}"
      subject = "API Transaction Count Report - #{report_date}"

      report_configs.each do |report_hash|
        reports = api_transaction_emailable_reports(report_hash['issuers'])

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
