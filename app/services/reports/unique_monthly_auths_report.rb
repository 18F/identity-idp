require 'login_gov/hostdata'

module Reports
  class UniqueMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'unique-monthly-auths-report'.freeze

    def call
      auth_counts = transaction_with_timeout do
        Db::MonthlyAuthCount::UniqueMonthlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json)
    end
  end
end
