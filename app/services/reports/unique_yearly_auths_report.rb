require 'login_gov/hostdata'

module Reports
  class UniqueYearlyAuthsReport < BaseReport
    REPORT_NAME = 'unique-yearly-auths-report'.freeze

    def call
      auth_counts = transaction_with_timeout do
        Db::MonthlyAuthCount::UniqueYearlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json)
    end
  end
end
