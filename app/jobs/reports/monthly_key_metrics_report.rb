require 'csv'
require 'reporting/command_line_options'
require 'reporting/monthly_proofing_report'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def perform(date = Time.zone.today)
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - Monthly Key Metrics Report NOT SENT'
        return false
      end

      reports = [
        total_user_count_report.total_user_count_emailable_report,
        account_deletion_rate_report.account_deletion_emailable_report,
        account_reuse_report.account_reuse_emailable_report,
        account_reuse_report.total_identities_emailable_report,
      ]

      # account_reuse_table = account_reuse_report.account_reuse_report
      # total_profiles_table = account_reuse_report.total_identities_report
      # document_upload_proofing_table = monthly_proofing_report
      # account_deletion_rate_table = account_deletion_rate_report.account_deletion_report
      # total_user_count_table = total_user_count_report.total_user_count_report

      # upload_to_s3(account_reuse_table, report_name: 'account_reuse')
      # upload_to_s3(total_profiles_table, report_name: 'total_profiles')
      # upload_to_s3(document_upload_proofing_table, report_name: 'document_upload_proofing')
      # upload_to_s3(account_deletion_rate_table, report_name: 'account_deletion_rate')
      # upload_to_s3(total_user_count_table, report_name: 'total_user_count')

      # email_tables = [
      #   [
      #     {
      #       title: "IDV app reuse rate #{account_reuse_report.stats_month}",
      #       float_as_percent: true,
      #       precision: 4,
      #     },
      #     *account_reuse_table,
      #   ],
      #   [
      #     { title: 'Total proofed identities' },
      #     *total_profiles_table,
      #   ],
      #   [
      #     { title: 'Document upload proofing rates' },
      #     *document_upload_proofing_table,
      #   ],
      #   [
      #     {
      #       title: 'Account deletion rate (last 30 days)',
      #       float_as_percent: true,
      #       precision: 4,
      #     },
      #     *account_deletion_rate_table,
      #   ],
      #   [
      #     {
      #       title: 'Total user count (all-time)',
      #     },
      #     *total_user_count_table,
      #   ],
      # ]

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.csv_name)
      end

      email_tables = reports.map do |report|
        [report.email_options, *report.table]
      end

      email_message = "Report: #{REPORT_NAME} #{date}"

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Monthly Key Metrics Report - #{date}",
        message: email_message,
        tables: email_tables,
      ).deliver_now
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

    def monthly_proofing_report
      prepared_report = []

      CSV.parse(get_raw_proofing_report).each do |row|
        unless row.first.start_with?('report')
          prepared_report << row
        end
      end

      prepared_report
    end

    def get_raw_proofing_report
      range_prev_month = Reporting::CommandLineOptions.new.time_range(
        date: @report_date.prev_month(1), period: :month,
      )

      Reporting::MonthlyProofingReport.new(
        time_range: range_prev_month, slice: 1.hour,
        threads: 10
      ).to_csv
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
