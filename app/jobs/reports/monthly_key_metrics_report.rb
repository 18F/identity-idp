require 'csv'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date)
      @report_date = date
      csv_for_email = monthly_key_metrics_report_csv

      emails.each do |email|
        ReportMailer.monthly_key_metrics_report(
          name: REPORT_NAME,
          email: email,
          csv_report: csv_for_email,
        ).deliver_now
      end
    end

    def emails
      emails = [IdentityConfig.store.team_agnes_email]
      if Identity::Hostdata.env == 'prod' && report_date.day == 1
        emails << IdentityConfig.store.team_all_feds_email
      end
      emails
    end

    def monthly_key_metrics_report_csv
      CSV.generate do |csv|
        account_reuse_report_csv.each do |row|
          csv << row
        end
      end
    end

    # Individual Key Metric Report
    def account_reuse_report_csv
      Reports::MonthlyAccountReuseReport.new(report_date: report_date).report_csv
    end
  end
end
