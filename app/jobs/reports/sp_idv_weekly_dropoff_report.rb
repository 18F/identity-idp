# frozen_string_literal: true

require 'reporting/sp_idv_weekly_dropoff_report'

module Reports
  class SpIdvWeeklyDropoffReport < BaseReport
    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled

      self.report_date = report_date

      IdentityConfig.store.sp_idv_weekly_dropoff_report_configs.each do |report_config|
        send_report(report_config)
      end
    end

    def send_report(report_config)
      report_start_date = Date.parse(report_config['report_start_date'])
      report_end_date = report_date.end_of_week(:sunday).weeks_ago(1).to_date
      issuers = report_config['issuers']
      agency_abbreviation = report_config['agency_abbreviation']
      emails = report_config['emails']

      agency_report_name = "#{agency_abbreviation.downcase}_idv_dropoff_report"
      agency_report_title = "#{agency_abbreviation} IdV Dropoff Report"

      report_maker = build_report_maker(
        issuers:,
        agency_abbreviation:,
        time_range: report_start_date..report_end_date,
      )

      save_report(agency_report_name, report_maker.to_csv, extension: 'csv')

      if emails.blank?
        Rails.logger.warn "No email addresses received - #{agency_report_title} NOT SENT"
        return false
      end

      message = <<~HTML.html_safe # rubocop:disable Rails/OutputSafety,
        <h2>#{agency_report_title}</h2>
      HTML

      emails.each do |email|
        ReportMailer.tables_report(
          email: email,
          subject: "#{agency_report_title} - #{report_date.to_date}",
          reports: report_maker.as_emailable_reports,
          message: message,
          attachment_format: :csv,
        ).deliver_now
      end
    end

    def build_report_maker(issuers:, agency_abbreviation:, time_range:)
      Reporting::SpIdvWeeklyDropoffReport.new(issuers:, agency_abbreviation:, time_range:)
    end
  end
end
