require 'csv'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date = Time.zone.today)
      @report_date = date

      reports = [
        total_user_count_report.total_user_count_emailable_report,
        account_deletion_rate_report.account_deletion_emailable_report,
        account_reuse_report.account_reuse_emailable_report,
        account_reuse_report.total_identities_emailable_report,
      ]

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.csv_name)
      end

      email_tables = reports.map do |report|
        [report.email_options, *report.table]
      end

      email_message = "Report: #{REPORT_NAME} #{date}"
      email_addresses = emails.select(&:present?)

      if !email_addresses.empty?
        ReportMailer.tables_report(
          email: email_addresses,
          subject: "Monthly Key Metrics Report - #{date}",
          message: email_message,
          tables: email_tables,
        ).deliver_now
      else
        Rails.logger.warn 'No email addresses received - Monthly Key Metrics Report NOT SENT'
      end
    end

    def emails
      emails = [IdentityConfig.store.team_agnes_email]
      if report_date.day == 1
        emails << IdentityConfig.store.team_all_feds_email
      end
      emails
    end

    def account_reuse_report
      @account_reuse_report ||= Reporting::AccountReuseAndTotalIdentitiesReport.new(report_date)
    end

    def account_deletion_rate_report
      @account_deletion_rate_report ||= Reporting::AccountDeletionRateReport.new(report_date)
    end

    def total_user_count_report
      @total_user_count_report ||= Reporting::TotalUserCountReport.new(report_date)
    end

    def upload_to_s3(report_body, report_name: nil)
      _latest, path = generate_s3_paths(REPORT_NAME, 'csv', subname: report_name, now: report_date)

      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: csv_file(report_body),
          content_type: 'text/csv',
          bucket: bucket_name,
        )
      end
    end

    def csv_file(report_array)
      CSV.generate do |csv|
        report_array.each do |row|
          csv << row
        end
      end
    end
  end
end
