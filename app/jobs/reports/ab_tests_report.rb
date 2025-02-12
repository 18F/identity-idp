# frozen_string_literal: true

require 'reporting/ab_tests_report'

module Reports
  class AbTestsReport < BaseReport
    attr_reader :report_date

    def initialize(report_date = nil, *args, **kwargs)
      @report_date = report_date
      super(*args, **kwargs)
    end

    # @param [DateTime]
    def perform(report_date)
      @report_date = report_date

      reported_ab_tests.each do |ab_test|
        tables_report(ab_test).deliver_now
      end
    end

    def tables_report(ab_test)
      experiment_name = ab_test.experiment_name
      subject = "A/B Tests Report - #{experiment_name} - #{report_date}"
      report = ab_tests_report(ab_test)

      ReportMailer.tables_report(
        email: ab_test.report.email,
        subject:,
        message: [subject, report.participants_message].compact,
        reports: report.as_emailable_reports,
        attachment_format: :csv,
      )
    end

    def ab_tests_report(ab_test)
      Reporting::AbTestsReport.new(
        ab_test:,
        time_range: report_date.yesterday..report_date,
      )
    end

    private

    def reported_ab_tests
      AbTests
        .all
        .values
        .select { |ab_test| ab_test.report&.email&.present? && ab_test.active? }
    end
  end
end
