# frozen_string_literal: true

require 'csv'
require 'reporting/irs_verification_report'

module Reports
  class IrsVerificationReport < BaseReport
    REPORT_NAME = 'irs-verification-report'

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
        title: 'IRS Verification Report',
        email: email_addresses,
        subject: "IRS Verification Report - #{report_date.to_date}",
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

    def previous_week_range
      today = Time.zone.today
      last_sunday = today.beginning_of_week(:sunday) - 7.days
      last_saturday = last_sunday + 6.days

      last_sunday.beginning_of_day..last_saturday.end_of_day
    end

    def irs_verification_report
      @irs_verification_report ||= Reporting::IrsVerificationReport.new(
        time_range: previous_week_range,
        issuers: IdentityConfig.store.irs_verification_report_issuers || [],
        # issuers: ['urn:gov:gsa:openidconnect.profiles:sp:sso:irs:sample'], # Make dynamic
      )
    end

    def emails
      emails = [*IdentityConfig.store.irs_verification_report_config]
      if report_date.next_day.day == 1
        emails += IdentityConfig.store.team_all_login_emails
      end
      emails
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