require 'csv'
require 'reporting/monthly_proofing_report'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def initialize(*args, report_date: nil, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

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
        monthly_proofing_report.document_upload_proofing_emailable_report,
      ]

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
      @monthly_proofing_report ||= Reporting::MonthlyProofingReport.new(
        # FYI - we should look for a way to share these configs
        time_range: @report_date.prev_month(1).in_time_zone('UTC').all_month,
        slice: 1.hour,
        threads: 10,
      )
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
