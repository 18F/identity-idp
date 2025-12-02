# frozen_string_literal: true

require 'csv'
require 'reporting/api_transaction_count_report'

module Reports
  class MonthlyApiTransactionCountReport < BaseReport
    REPORT_NAME = 'monthly-api-transaction-count-report'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.today.beginning_of_month.yesterday.end_of_day)
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - API Transaction Count Report NOT SENT'
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Monthly API Transaction Count Report -
                   #{previous_month_range.first.strftime('%B %Y')}",
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
      @reports ||= api_transaction_count_report.as_emailable_reports
    end

    def previous_month_range
      today = Time.zone.today
      last_month = today.beginning_of_month - 1.month
      last_month.beginning_of_month.beginning_of_day..last_month.end_of_month.end_of_day
    end

    def api_transaction_count_report
      @api_transaction_count_report ||= Reporting::ApiTransactionCountReport.new(
        time_range: previous_month_range,
      )
    end

    def emails
      [*IdentityConfig.store.api_transaction_count_report_config]
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
