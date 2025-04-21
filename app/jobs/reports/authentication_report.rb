# frozen_string_literal: true

require 'reporting/authentication_report'

module Reports
  class AuthenticationReport < BaseReport
    REPORT_NAME = 'authentication-report'

    attr_accessor :report_date

    def perform(_date)
      return unless IdentityConfig.store.s3_reports_enabled
    
      iaas = IaaReportingHelper.iaas.filter { |x| x.end_date > 90.days.ago }
      csv = build_csv(iaas, IaaReportingHelper.partner_accounts)
      file_path = save_report(REPORT_NAME, csv, extension: 'csv')
    
      message = "Report: #{REPORT_NAME}"
      subject = "IRS Combined Invoice Supplement Report"
    
      report_configs.each do |report_hash|
        report_hash['emails'].each do |email|
          ReportMailer.file_report(
            email:,
            subject:,
            message:,
            file_path:,
            filename: "#{REPORT_NAME}.csv",
          ).deliver_now
        end
      end
    end

    private

    def weekly_authentication_emailable_reports(issuers)
      Reporting::AuthenticationReport.new(
        issuers:,
        time_range: report_date.all_week,
      ).as_emailable_reports
    end

    def report_configs
      IdentityConfig.store.weekly_auth_funnel_report_config
    end
  end
end
