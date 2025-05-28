# frozen_string_literal: true

require 'csv'
# require 'reporting/proofing_rate_report'
# require 'reporting/monthly_idv_report'

module Reports
  class IrsCredentialTenureReport < BaseReport
    REPORT_NAME = 'irs-credential-tenure-report'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day)
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
        subject: "IRS Credential Tenure Report - #{date.to_date}",
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

    def reports
      @reports ||= [
        # account_deletion_rate_report.account_deletion_emailable_report,
        irs_credential_tenure_definition.irs_credential_tenure_definition,
        irs_credential_tenure_report.credential_tenure_emailable_report,
      ]
    end

    def emails
      emails = [*IdentityConfig.store.irs_verification_report_config]
      if report_date.next_day.day == 1
        emails += IdentityConfig.store.team_all_login_emails
      end
      emails
    end

    def irs_credential_tenure_report
      @irs_credential_tenure_report ||= Reporting::IrsCredentialTenureReport.new(report_date)
    end

    def irs_credential_tenure_definition
      @irs_credential_tenure_definition ||= Reporting::IrsCredentialTenureReport.new(report_date)
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
