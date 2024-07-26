# frozen_string_literal: true

require 'reporting/drop_off_report'

module Reports
  class DropOffReport < BaseReport
    REPORT_NAME = 'drop-off-report'

    attr_accessor :report_date

    # Generate a drop off report for the week including the passed timestamp
    # @param [DateTime]
    def perform(report_date)
      self.report_date = report_date

      subject = "Drop Off Report - #{report_date.to_date}"
      configs.each do |config|
        reports = [report_maker(config['issuers']).as_emailable_reports].flatten
        config['emails'].each do |email|
          ReportMailer.tables_report(
            email: email,
            subject: subject,
            message: preamble,
            reports: reports,
            attachment_format: :csv,
          ).deliver_now
        end
      end
    end

    def preamble
      <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
        <h2>
          Drop Off Report
        </h2>
      HTML
    end

    def configs
      IdentityConfig.store.drop_off_report_config
    end

    def report_maker(issuers)
      Reporting::DropOffReport.new(
        issuers: issuers,
        time_range: report_date.all_week,
        slice: 1.week,
      )
    end
  end
end
