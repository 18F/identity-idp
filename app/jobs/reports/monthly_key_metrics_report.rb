require 'csv'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date = Time.zone.today)
      @report_date = date

      account_reuse_table = account_reuse_report.account_reuse_report
      total_profiles_table = account_reuse_report.total_identities_report

      upload_to_s3(account_reuse_table, report_name: 'account_reuse')
      upload_to_s3(total_profiles_table, report_name: 'total_profiles')

      email_tables = [
        [
          {
            title: "IDV app reuse rate #{account_reuse_report.stats_month}",
            float_as_percent: true,
            precision: 4,
          },
          *account_reuse_table,
        ],
        [
          { title: 'Total proofed identities' },
          *total_profiles_table,
        ],
      ]

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
