require 'csv'
require 'reporting/proofing_rate_report'

module Reports
  class MonthlyKeyMetricsReport < BaseReport
    REPORT_NAME = 'monthly-key-metrics-report'.freeze

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday)
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
    def preamble(env: Identity::Hostdata.env || 'local')
      ERB.new(<<~ERB).result(binding).html_safe # rubocop:disable Rails/OutputSafety
        <% if env != 'prod' %>
          <div class="usa-alert usa-alert--info">
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

    def reports
      @reports ||= [
        active_users_count_report.active_users_count_emailable_report,
        total_user_count_report.total_user_count_emailable_report,
        proofing_rate_report.proofing_rate_emailable_report,
        account_deletion_rate_report.account_deletion_emailable_report,
        account_reuse_report.account_reuse_emailable_report,
        agency_and_sp_report.agency_and_sp_emailable_report,
        active_users_count_report.active_users_count_apg_emailable_report,
      ]
    end

    def emails
      emails = [IdentityConfig.store.team_agnes_email]
      if report_date.next_day.day == 1
        emails << IdentityConfig.store.team_all_feds_email
        emails << IdentityConfig.store.team_all_contractors_email
      end
      emails
    end

    def proofing_rate_report
      @proofing_rate_report ||= Reporting::ProofingRateReport.new(end_date: report_date)
    end

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
