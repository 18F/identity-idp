# frozen_string_literal: true

require 'csv'
require 'reporting/irs_verification_report'

module Reports
  class MonthlyIrsVerificationReport < BaseReport
    REPORT_NAME = 'monthly-irs-verification-report'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date

      email_addresses = emails.select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn 'No email addresses received - IRS Verification Report NOT SENT'
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: email_addresses,
        subject: "Monthly IRS Verification Report - #{report_date.to_date}",
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
      @reports ||= irs_verification_report.as_emailable_reports
    end

    def irs_verification_report
      @irs_verification_report ||= Reporting::IrsVerificationReport.new(
        time_range: report_date.all_month,
        issuers: IdentityConfig.store.irs_verification_report_issuers || [],
      )
    end

    def emails
      [*IdentityConfig.store.irs_verification_report_config]
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
