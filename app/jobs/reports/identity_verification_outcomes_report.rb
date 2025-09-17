require 'csv'
require 'reporting/identity_verification_outcomes_report'
module Reports
  class IdentityVerificationOutcomesReport < BaseReport
    REPORT_NAME = 'identity-verification-outcomes-report'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day) # modify this for testing to be start_of_day to see if values match
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - Registration Funnel Report NOT SENT'
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Identity Verification Outcomes Report - #{report_date.to_date}",
        reports: reports,
        message: preamble,
        attachment_format: :csv,
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
      ERB
    end

    def reports
      @reports ||= identity_verification_outcomes_report.as_emailable_reports
    end

    def identity_verification_outcomes_report
      @identity_verification_outcomes_report ||= Reporting::IdentityVerificationOutcomesReport.new(
        issuers: issuers,
        time_range: report_date.all_month,
      )
    end

    # these two need to be saved in the config file application.yml.default as empty '[]'
    def issuers
      [*IdentityConfig.store.identity_verification_outcomes_report_issuers]
    end

    def emails
      [*IdentityConfig.store.identity_verification_outcomes_report_emails]
    end
    # -------------------------------------------------------------------

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
