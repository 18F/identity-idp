# frozen_string_literal: true

require 'csv'
require 'reporting/irs_fraud_metrics_lg99_report'

module Reports
  class IrsFraudMetricsReport < BaseReport
    REPORT_NAME = 'irs-fraud-metrics-report'

    attr_reader :report_date, :report_receiver

    def initialize(init_date = nil, init_receiver = :internal, *args, **rest)
      @report_date = init_date
      @report_receiver = init_receiver.to_sym
      super(init_date, init_receiver, *args, **rest)
    end

    def perform(perform_date = Time.zone.yesterday.end_of_day, perform_receiver = :internal)
      @report_date = perform_date
      @report_receiver = perform_receiver.to_sym

      email_addresses = emails
      to_emails = email_addresses[:to].select(&:present?)
      bcc_emails = email_addresses[:bcc].select(&:present?)

      if to_emails.empty?
        Rails.logger.warn 'No email addresses received - Fraud Metrics Report NOT SENT'
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: to_emails,
        bcc: bcc_emails,
        subject: "IRS Fraud Metrics Report - #{report_date.to_date}",
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
      @reports ||= irs_fraud_metrics_lg99_report.as_emailable_reports
    end

    def irs_fraud_metrics_lg99_report
      @irs_fraud_metrics_lg99_report ||= Reporting::IrsFraudMetricsLg99Report.new(
        issuers: issuers,
        time_range: report_date.all_month,
      )
    end

    def issuers
      [*IdentityConfig.store.irs_fraud_metrics_issuers]
    end

    def emails
      internal_emails = [*IdentityConfig.store.team_daily_reports_emails].select(&:present?)
      irs_emails      = [*IdentityConfig.store.irs_fraud_metrics_emails].select(&:present?)

      # Case 1: internal-only OR IRS list is empty - send internal only
      if report_receiver == :internal || irs_emails.empty?
        return { to: internal_emails, bcc: [] }
      end

      # Case 2: receiver = both AND IRS emails exist
      if report_receiver == :both
        return { to: irs_emails, bcc: internal_emails }
      end

      # fallback
      { to: [], bcc: [] }
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
