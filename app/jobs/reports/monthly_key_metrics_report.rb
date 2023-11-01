require 'csv'
require 'reporting/monthly_proofing_report'
require 'reporting/proofing_rate_report'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
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

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Monthly Key Metrics Report - #{date}",
        reports: reports,
        message: preamble,
        attachment_format: :xlsx,
      ).deliver_now
    end

    # Explanatory text to go before the report in the email
    # @return [String]
    def preamble
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <p>
          For more information on how each of these metrics are calculated, take a look at our
          <a href="https://handbook.login.gov/articles/monthly-key-metrics-explainer.html">
          Monthly Key Metrics Report Explainer document</a>.
        </p>
      HTML
    end

    def reports
      @reports ||= [
        # Number of verified users (total) - LG-11148
        # Number of verified users (new) - LG-11164
        active_users_count_report.active_users_count_emailable_report,
        # Total Annual Users - LG-11150
        total_user_count_report.total_user_count_emailable_report,
        proofing_rate_report.proofing_rate_emailable_report,
        account_deletion_rate_report.account_deletion_emailable_report,
        account_reuse_report.account_reuse_emailable_report,
        account_reuse_report.total_identities_emailable_report,
        monthly_proofing_report.document_upload_proofing_emailable_report,
        agency_and_sp_report.agency_and_sp_emailable_report,
        active_users_count_report.active_users_count_apg_emailable_report,
        # APG Reporting of Active Federal Partner Agencies - LG-11157
        # APG Reporting of Active Login.gov Serviced Applications - LG-11158
        # APG Reporting of Cumulative Proofed Identities By Year/Month - LG-11159
        # APG Reporting Proofing rate for HISPs - LG-11160
      ]
    end

    def emails
      emails = [IdentityConfig.store.team_agnes_email]
      if report_date.day == 1
        emails << IdentityConfig.store.team_all_feds_email
        emails << IdentityConfig.store.team_all_contractors_email
      end
      emails
    end

    def proofing_rate_report
      @proofing_rate_report ||= Reporting::ProofingRateReport.new(end_date: report_date)
    end

    def account_reuse_report
      @account_reuse_report ||= Reporting::AccountReuseAndTotalIdentitiesReport.new(report_date)
    end

    def monthly_proofing_report
      @monthly_proofing_report ||= Reporting::MonthlyProofingReport.new(
        # FYI - we should look for a way to share these configs
        time_range: @report_date.in_time_zone('UTC').all_month,
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

    def active_users_count_report
      @active_users_count_report ||= Reporting::ActiveUsersCountReport.new(
        report_date,
      )
    end

    def agency_and_sp_report
      @agency_and_sp_report ||= Reporting::AgencyAndSpReport.new(report_date)
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
