require 'csv'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date)
      @report_date = date
      csv_for_email = monthly_key_metrics_report_array
      email_message = "Report: #{REPORT_NAME} #{date}"
      email_addresses = emails.select(&:present?)

      if !email_addresses.empty?
        ReportMailer.tables_report(
          email: email_addresses,
          subject: "Monthly Key Metrics Report - #{date}",
          message: email_message,
          tables: csv_for_email,
        ).deliver_now
      else
        Rails.logger.warn 'No email addresses received - Monthly Key Metrics Report NOT SENT'
      end
    end

    def emails
      emails = [IdentityConfig.store.team_agnes_email]
      if Identity::Hostdata.env == 'prod' && report_date.day == 1
        emails << IdentityConfig.store.team_all_feds_email
      end
      emails
    end

    def monthly_key_metrics_report_array
      csv_array = []

      account_reuse_report_csv.each do |row|
        csv_array << row
      end

      csv_array
    end

    # Individual Key Metric Report
    def account_reuse_report_csv
      Reports::MonthlyAccountReuseReport.new(report_date).report_csv
    end
  end
end
