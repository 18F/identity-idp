require 'identity/hostdata'

module Reports
  class SpActiveUsersOverPeriodOfPerformanceReport < BaseReport
    REPORT_NAME = 'sp-active-users-over-period-of-performance-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.call(arbitrary_start_day(month: 4, day: 1))
      end
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
