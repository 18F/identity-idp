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

      report_configs.each do |config|
        tables_report(config).deliver_now
      end
    end

    def tables_report(config)
      experiment_name = config[:experiment_name]
      subject = "A/B Tests Report - #{experiment_name} - #{report_date}"
      reports = ab_tests_report(config).as_emailable_reports

      ReportMailer.tables_report(
        email: config[:email],
        subject:,
        message: subject,
        reports:,
        attachment_format: :csv,
      )
    end

    def ab_tests_report(config)
      Reporting::AbTestsReport.new(
        queries: config[:queries],
        time_range: report_date.yesterday..report_date,
      )
    end

    private

    def report_configs
      AbTests
        .all
        .values
        .select { |ab_test| ab_test.report&.[](:email)&.present? && ab_test.active? }
        .map { |ab_test| ab_test.report.merge(experiment_name: ab_test.experiment_name) }
    end
  end
end
