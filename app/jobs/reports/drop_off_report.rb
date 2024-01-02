require 'reporting/identity_verification_report'

module Reports
	class DropOffReport < BaseReport
		REPORT_NAME = 'drop-off-report'

		attr_accessor :report_date

		def perform(report_date, issuers)
			return unless IdentityConfig.store.s3_reports_enabled
			
			self.report_date = report_date
      message = "Report: #{REPORT_NAME} #{report_date}"
      subject = "Drop Off Report - #{report_date}"

      tables = weekly_drop_off_report_tables(issuers).to_csv
    end

    private

    def weekly_drop_off_report_tables(issuers)
      Reporting::IdentityVerificationReport.new(
        issuers: issuers,
        time_range: report_date.all_month,
        slice: 1.month,
      )
    end

    def report_configs
      IdentityConfig.store.weekly_auth_funnel_report_config
    end 	
	end
end



