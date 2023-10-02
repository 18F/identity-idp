require 'reporting/authentication_report'

module Reports
  class AuthenticationReport < BaseReport
    REPORT_NAME = 'authentication-report'

    attr_accessor :report_date

    def perform(report_date)
      return unless IdentityConfig.store.s3_reports_enabled
      self.report_date = report_date

      report_configs.each do |report_hash|
        issuers = report_hash['issuers']
        emails = report_hash['emails']
        name = report_hash['name']
        data = report_maker(issuers).to_csv

        emails.each do |email|
          ReportMailer.authentication_report(
            email:,
            name:,
            issuers:,
            data:,
          ).deliver_now
        end
      end
    end

    def report_maker(issuers)
      Reporting::AuthenticationReport.new(
        issuers:,
        time_range: report_date.all_week,
      )
    end

    def report_configs
      IdentityConfig.store.weekly_auth_funnel_report_config
    end
  end
end
