# frozen_string_literal: true

require 'csv'
require 'reporting/monthly_key_metrics_idv_s3_report'
require 'reporting/account_reuse_report'
require 'reporting/account_deletion_rate_report'
require 'reporting/total_user_count_report'
require 'reporting/active_users_count_report'
require 'reporting/agency_and_sp_report'

module Reports
  # S3-backed variant of MonthlyKeyMetricsReport.
  #
  # Identical to MonthlyKeyMetricsReport except the two CloudWatch-derived tables
  # (condensed IDV + proofing rate) are no longer generated in-app. Instead they are
  # generated in reporting-rails from Redshift, uploaded to S3, and read back here.
  #
  # If either S3 file is missing or stale, the ENTIRE report is aborted (we do not
  # send a partial Key Metrics email).
  class MonthlyKeyMetricsS3Report < BaseReport
    REPORT_NAME = 'MonthlyKeyMetricsIdvS3Report'

    # The two IDV files are expected to have been uploaded by reporting-rails within
    # a few days of the report date.
    MAX_FILE_AGE_DAYS = 5

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(report_date, *args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - Monthly Key Metrics S3 Report NOT SENT'
        return false
      end

      # Abort the whole report if the S3-backed IDV files are missing or stale.
      # We do not send a partial Key Metrics email.
      unless idv_s3_reports_available?
        Rails.logger.error(
          "#{REPORT_NAME}: IDV S3 reports unavailable or stale - Monthly Key Metrics " \
          "S3 Report NOT SENT",
        )
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        to: email_addresses,
        subject: "Monthly Key Metrics Report NEW - #{date.to_date}",
        reports: reports,
        message: preamble,
        attachment_format: :xlsx,
      ).deliver_now
    end

    # Explanatory text to go before the report in the email
    # @return [String]
    def preamble(env: Identity::Hostdata.env || 'local')
      ERB.new(<<~ERB).result(binding).html_safe # rubocop:disable Rails/OutputSafety
        <% if env != 'prod' %>
          <div class="usa-alert usa-alert--info usa-alert--email">
            <div class="usa-alert__body">
              <%#
                NOTE: our AlertComponent doesn't support heading content like this uses,
                so for a one-off outside the Rails pipeline it was easier to inline the HTML here.
              %>
              <h2 class="usa-alert__heading">
                Non-Production Report
              </h2>
              <p class="usa-alert__text">
                This was generated in the <strong><%= env %></strong> environment.
              </p>
            </div>
          </div>
        <% end %>
        <p>
          For more information on how each of these metrics are calculated, take a look at our
          <a href="https://handbook.login.gov/articles/monthly-key-metrics-explainer.html">
          Monthly Key Metrics Report Explainer document</a>.
        </p>
      ERB
    end

    # Same ordering as MonthlyKeyMetricsReport, but the two CloudWatch-derived tables
    # (monthly_idv + proofing_rate) now come from the S3 reader instead of the in-app
    # reporting classes.
    def reports
      @reports ||= [
        active_users_count_report.active_users_count_emailable_report,
        total_user_count_report.total_user_count_emailable_report,
        idv_s3_report.condensed_idv_emailable_report,
        idv_s3_report.proofing_rate_emailable_report,
        account_deletion_rate_report.account_deletion_emailable_report,
        account_reuse_report.account_reuse_emailable_report,
        agency_and_sp_report.agency_and_sp_emailable_report,
        active_users_count_report.active_users_count_apg_emailable_report,
      ]
    end

    def emails
      emails = [*IdentityConfig.store.team_daily_reports_emails]
      if report_date.next_day.day == 1
        emails += IdentityConfig.store.team_all_login_emails
      end
      emails
    end

    # --- Database-backed reports (unchanged from MonthlyKeyMetricsReport) ---

    def account_reuse_report
      @account_reuse_report ||= Reporting::AccountReuseReport.new(report_date)
    end

    def account_deletion_rate_report
      @account_deletion_rate_report ||= Reporting::AccountDeletionRateReport.new(report_date)
    end

    def total_user_count_report
      @total_user_count_report ||= Reporting::TotalUserCountReport.new(report_date)
    end

    def active_users_count_report
      @active_users_count_report ||= Reporting::ActiveUsersCountReport.new(report_date)
    end

    def agency_and_sp_report
      @agency_and_sp_report ||= Reporting::AgencyAndSpReport.new(report_date)
    end

    def idv_s3_report
      @idv_s3_report ||= Reporting::MonthlyKeyMetricsIdvS3Report.new(
        bucket_name: data_warehouse_bucket_name,
        custom_s3_path: idv_s3_path,
      )
    end

    # --- S3-backed IDV reports (replaces CloudWatch-based monthly_idv + proofing_rate) ---

    # Builds the S3 key prefix so that the reader appending "_<filename>.csv"
    # reproduces the key reporting-rails wrote in #paths_for:
    #   <base>idp/MonthlyKeyMetricsIdvS3Report/<YYYY>/<MM>/<YYYYMMDD>_monthly_<filename>.csv
    def idv_s3_path
      report_day = report_date.to_date
      date_prefix = report_day.strftime('%Y%m%d')
      year = report_day.strftime('%Y')
      month = report_day.strftime('%m')

      base_path = generate_base_s3_path(directory: 'idp')

      "#{base_path}#{REPORT_NAME}/#{year}/#{month}/#{date_prefix}_monthly"
    end

    # Confirms both IDV CSVs exist in S3 and are recent enough. If any file is missing
    # or stale, the whole report is aborted (no partial email).
    def idv_s3_reports_available?
      bucket = data_warehouse_bucket_name
      if bucket.blank?
        Rails.logger.error "#{REPORT_NAME}: data warehouse bucket name is blank"
        return false
      end

      cutoff_time = MAX_FILE_AGE_DAYS.days.ago

      idv_s3_report.csv_file_names.all? do |file_name|
        begin
          last_modified = idv_s3_report.get_file_last_modified(file_name)

          if last_modified <= cutoff_time
            Rails.logger.error(
              "#{REPORT_NAME}: IDV S3 report '#{file_name}' is stale " \
              "(last modified #{last_modified}, cutoff #{cutoff_time}) - " \
              "key: #{idv_s3_path}_#{file_name}.csv",
            )
            next false
          end

          true
        rescue Aws::S3::Errors::NoSuchKey
          Rails.logger.error(
            "#{REPORT_NAME}: IDV S3 report '#{file_name}' not found - " \
            "key: #{idv_s3_path}_#{file_name}.csv, bucket: #{bucket}",
          )
          false
        end
      end
    end

    # --- S3 upload (unchanged from MonthlyKeyMetricsReport) ---

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

    # Bucket where reporting-rails uploaded the IDV CSVs (same data-warehouse replica
    # bucket used by the demographics S3 reader).
    def data_warehouse_bucket_name
      bucket_prefix = IdentityConfig.store.s3_data_warehouse_replica_bucket_prefix
      aws_account_id = Identity::Hostdata.aws_account_id
      aws_region = Identity::Hostdata.aws_region
      "#{bucket_prefix}-#{aws_account_id}-#{aws_region}"
    end
  end
end
