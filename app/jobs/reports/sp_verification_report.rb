# frozen_string_literal: true

require 'csv'
require 'reporting/sp_verification_report'

module Reports
  class SPVerificationReport < BaseReport
    # REPORT_NAME = 'irs-verification-report'

    attr_reader :report_date, :report_receiver, :report_name, :report_title

    def initialize(report_date = nil, report_receiver = :internal, *args, **rest)
      @report_date = report_date
      @report_receiver = report_receiver.to_sym
      super(*args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day)
      @report_date = date

      IdentityConfig.store.sp_verification_report_configs.each do |report_config|
        send_report(report_config)
      end
    end

    def send_report(report_config)

      issuers = report_config['issuers']
      agency_abbreviation = report_config['agency_abbreviation']
      irs_emails = report_config['irs_emails']
      internal_emails = report_config['internal_emails']

      @report_name = "#{agency_abbreviation.downcase}_verification_report"
      @report_title = "#{agency_abbreviation} Verification Report"

      email_addresses = emails(internal_emails,irs_emails).select(&:present?)
      if email_addresses.empty?
        Rails.logger.warn "No email addresses received - #{@report_title} NOT SENT"
        return false
      end

      emailable_reports = reports(issuers, agency_abbreviation)
      
      emailable_reports.each do |report|
        upload_to_s3(report.table, report_name: report.filename)
      end

      ReportMailer.tables_report(
        email: email_addresses,
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
      @reports ||= sp_verification_report(issuers, agency_abbreviation).as_emailable_reports
    end

    def previous_week_range
      @report_date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday)
    end

    def sp_verification_report(issuers, agency_abbreviation)
      @irs_verification_report ||= Reporting::SPVerificationReport.new(
        time_range: previous_week_range,
        issuers: issuers || [],
        agency_abbreviation: agency_abbreviation,
      )
    end

    def emails(internal_emails,irs_emails)
      # internal_emails = [*IdentityConfig.store.team_daily_reports_emails]
      # irs_emails = [*IdentityConfig.store.irs_verification_report_config]

      case report_receiver
      when :internal then internal_emails
      when :both then (internal_emails + irs_emails)
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
