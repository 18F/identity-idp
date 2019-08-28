require 'login_gov/hostdata'

module Reports
  class TotalMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'total-monthly-auths-report'.freeze

    def call
      auth_counts = transaction_with_timeout do
        Db::MonthlyAuthCount::TotalMonthlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json)
    end
  end
end
