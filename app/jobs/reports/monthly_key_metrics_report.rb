require 'csv'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date = Time.zone.today)
      @report_date = date

      account_reuse_table = account_reuse_queries.account_reuse_report
      total_profiles_table = account_reuse_queries.total_identities_report
      total_users_all_time_table = total_user_queries.total_user_count_report

      upload_to_s3(account_reuse_data, report_name: 'account_reuse')
      upload_to_s3(total_profiles_data, report_name: 'total_profiles', )
      upload_to_s3(total_users_all_time_table, report_name: 'total_users_all_time')

      email_tables = [
        [
          {
          title: "IDV app reuse rate #{account_reuse_queries.stats_month}",
          float_as_percent: true,
          precision: 4,
          },
          account_reuse_table
        ], 
        [
          { title: 'Total proofed identities' },
          total_profiles_table,
        ],
        [
          { title: 'All-time user total' },
          total_users_all_time_table,
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

    def account_reuse_queries
      @account_reuse_queries ||= AccountReuseAndTotalIdentities.new(report_date)
    end

    def total_user_queries
      @total_user_queries ||= Reporting::TotalUserCountReport.new(report_date)
    end

    def upload_to_s3(report_body, report_name: nil)

      _latest, path = generate_s3_paths(REPORT_NAME, 'csv', subname: report_name, now: report_date)

      if bucket_name.present?
        upload_file_to_s3_bucket(
          path: path,
          body: report_body,
          content_type: 'text/csv',
          bucket: bucket_name,
        )
      end
    end
  end
end
