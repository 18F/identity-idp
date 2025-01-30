# frozen_string_literal: true

require 'reporting/sp_proofing_events_by_uuid'

module Reports
  class SpProofingEventsByUuid < BaseReport
    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled

      self.report_date = report_date

      IdentityConfig.store.sp_proofing_events_by_uuid_report_configs.each do |report_config|
        send_report(report_config)
      end
    end

    def send_report(report_config)
      return unless IdentityConfig.store.s3_reports_enabled
      issuers = report_config['issuers']
      agency_abbreviation = report_config['agency_abbreviation']
      emails = report_config['emails']

      agency_report_nane = "#{agency_abbreviation.downcase}_proofing_events_by_uuid"
      agency_report_title = "#{agency_abbreviation} Proofing Events By UUID"

      report_maker = build_report_maker(
        issuers:,
        agency_abbreviation:,
        time_range: report_date.to_date.weeks_ago(1).all_week(:sunday),
      )

      csv = report_maker.to_csv

      save_report(agency_report_nane, csv, extension: 'csv')

      if emails.blank?
        Rails.logger.warn "No email addresses received - #{agency_report_title} NOT SENT"
        return false
      end

      email_message = <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <h2>#{agency_report_title}</h2>
      HTML

      emails.each do |email|
        ReportMailer.tables_report(
          email: email,
          subject: "#{agency_report_title} - #{report_date.to_date}",
          reports: report_maker.as_emailable_reports,
          message: email_message,
          attachment_format: :csv,
        ).deliver_now
      end
    end

    def build_report_maker(issuers:, agency_abbreviation:, time_range:)
      Reporting::SpProofingEventsByUuid.new(issuers:, agency_abbreviation:, time_range:)
    end
  end
end
