require 'reporting/identity_verification_report'

module Reports
  class IdentityVerificationReport < BaseReport
    REPORT_NAME = 'identity-verification-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled
      self.report_date = report_date

      csv = report_maker.to_csv

      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    def report_maker
      Reporting::IdentityVerificationReport.new(
        issuers: [],
        time_range: report_date.all_day,
        slice: 4.hours,
      )
    end
  end
end
