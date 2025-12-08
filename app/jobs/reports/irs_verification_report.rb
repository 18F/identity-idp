# frozen_string_literal: true

require 'csv'
require 'reporting/irs_verification_report'

module Reports
  class IrsVerificationReport < BaseReport
    REPORT_NAME = 'irs-verification-report'

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
        Rails.logger.warn 'No To email addresses received - IRS Verification Report NOT SENT'
        return false
      end

      reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: to_emails,
        bcc: bcc_emails,
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
      @report_date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday)
    end

    def irs_verification_report
      @irs_verification_report ||= Reporting::IrsVerificationReport.new(
        time_range: previous_week_range,
        issuers: IdentityConfig.store.irs_verification_report_issuers || [],
      )
    end

    def emails
      internal_emails = [*IdentityConfig.store.team_daily_reports_emails]
      irs_emails = [*IdentityConfig.store.irs_verification_report_config]

      case report_receiver
      when :internal
        { to: internal_emails, bcc: [] }
      when :both
        { to: irs_emails, bcc: internal_emails }
      else
        { to: [], bcc: [] }
      end
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
