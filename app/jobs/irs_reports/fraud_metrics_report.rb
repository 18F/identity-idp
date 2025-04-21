# frozen_string_literal: true

require 'csv'
require 'irs_reporting/fraud_metrics_lg99_report'

module IrsReports
  class FraudMetricsReport < Reports::BaseReport
    REPORT_NAME = 'fraud-metrics-report'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date

      report_configs.each do |config|
        run_report(config)
      end
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

    def report_configs
      IdentityConfig.store.monthly_fraud_metrics_report_config
    end

    def run_report(config)
      date_anchor = report_date.is_a?(Date) ? report_date.in_time_zone.end_of_day : report_date # Ensures CloudWatchClient always receives time arguments to avoid the ArgumentError associated with Date objects
      
      issuers = Array(config['issuers']).select(&:present?)
      email_addresses = Array(config['emails']).select(&:present?)

      if email_addresses.empty?
        Rails.logger.warn "No e-mails configured for issuers #{issuers.inspect} - report not sent"
        return
      end

      reports = IrsReporting::FraudMetricsLg99Report.new(
        time_range: date_anchor.all_month,
        issuers: issuers,
      )

      reports.as_emailable_reports. each do |report|
        upload_to_s3(
          report.table,
          report_name: "#{issuers.first}_#{report.filename}",
          )
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Fraud Metrics Report - #{report_date.to_date}",
        reports: reports.as_emailable_reports,
        message: preamble,
        attachment_format: :xlsx
      ).deliver_now
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
