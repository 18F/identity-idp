# frozen_string_literal: true

require 'csv'
require 'reporting/sp_fraud_metrics_lg99_report'

module Reports
  class SpFraudMetricsReport < BaseReport
    attr_reader :report_date, :report_receiver, :report_name, :report_title

    def initialize(init_date = nil, init_receiver = :internal, *args, **rest)
      @report_date = init_date
      @report_receiver = init_receiver.to_sym
      super(init_date, init_receiver, *args, **rest)
    end

    def perform(perform_date = Time.zone.yesterday.end_of_day, perform_receiver = :internal)
      @report_date = perform_date
      @report_receiver = perform_receiver.to_sym

      IdentityConfig.store.sp_fraud_metrics_report_configs.each do |report_config|
        send_report(report_config)
      end
    end

    def send_report(report_config)
      issuers = report_config['issuers']
      agency_abbreviation = report_config['agency_abbreviation']
      partner_emails = report_config['partner_emails']
      internal_emails = report_config['internal_emails']

      @report_name = "#{agency_abbreviation.downcase}_fraud_metrics_report"
      @report_title = "#{agency_abbreviation} Fraud Metrics Report"

      email_addresses = emails(internal_emails, partner_emails)
      to_emails = email_addresses[:to].select(&:present?)
      bcc_emails = email_addresses[:bcc].select(&:present?)

      if to_emails.empty? && bcc_emails.empty?
        Rails.logger.warn "No email addresses received - #{@report_title} NOT SENT"
        return false
      end

      emailable_reports = reports(issuers, agency_abbreviation)

      emailable_reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        to: to_emails,
        bcc: bcc_emails,
        subject: "#{@report_title} - #{report_date.to_date}",
        reports: emailable_reports,
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

    def reports(issuers, agency_abbreviation)
      sp_fraud_metrics_lg99_report(issuers, agency_abbreviation).as_emailable_reports
    end

    def sp_fraud_metrics_lg99_report(issuers, agency_abbreviation)
      Reporting::SpFraudMetricsLg99Report.new(
        issuers: issuers || [],
        time_range: report_date.all_month,
        agency_abbreviation: agency_abbreviation,
      )
    end

    def emails(internal_emails, partner_emails)
      if report_receiver == :both && partner_emails.empty?
        Rails.logger.warn(
          "#{@report_title}: recipient is :both " \
          "but no external email specified",
        )
      end

      if report_receiver == :both && partner_emails.present?
        { to: partner_emails, bcc: internal_emails }
      else
        { to: internal_emails, bcc: [] }
      end
    end

    def upload_to_s3(report_body, report_name: nil)
      _latest, path = generate_s3_paths(@report_name, 'csv', subname: report_name, now: report_date)

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
