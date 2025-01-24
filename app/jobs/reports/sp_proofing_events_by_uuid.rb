# frozen_string_literal: true

require 'reporting/sp_proofing_events_by_uuid'

module Reports
  class SpProofingEventsByUuid < BaseReport
    attr_accessor :report_date, :issuers, :agency_abbreviation

    def perform(report_date, issuers, agency_abbreviation)
      return unless IdentityConfig.store.s3_reports_enabled
      self.report_date = report_date
      self.issuers = issuers
      self.agency_abbreviation = agency_abbreviation

      csv = report_maker.to_csv

      save_report(agency_report_nane, csv, extension: 'csv')

      email = IdentityConfig.store.team_ada_email
      if email.blank?
        Rails.logger.warn "No email addresses received - #{agency_report_title} NOT SENT"
        return false
      end

      ReportMailer.tables_report(
        email: email,
        subject: "#{agency_report_title} - #{report_date.to_date}",
        reports: reports,
        message: message,
        attachment_format: :csv,
      ).deliver_now
    end

    def agency_report_nane
      "#{agency_abbreviation.downcase}_proofing_events_by_uuid"
    end

    def agency_report_title
      "#{agency_abbreviation} Proofing Events By UUID"
    end

    def message
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <h2>#{agency_report_title}</h2>
      HTML
    end

    def reports
      report_maker.as_emailable_reports
    end

    def report_maker
      @report_maker ||= Reporting::SpProofingEventsByUuid.new(
        issuers:,
        agency_abbreviation:,
        time_range: report_date.all_week(:sunday),
      )
    end
  end
end
