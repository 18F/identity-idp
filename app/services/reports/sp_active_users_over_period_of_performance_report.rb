require 'identity/hostdata'

module Reports
  class SpActiveUsersOverPeriodOfPerformanceReport < BaseReport
    REPORT_NAME = 'sp-active-users-over-period-of-performance-report'.freeze

    def call
      results = transaction_with_timeout { Db::Identity::SpActiveUserCountsWithinIaaWindow.call }
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
