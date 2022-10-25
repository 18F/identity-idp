require 'identity/hostdata'

module Reports
  class SpActiveUsersOverPeriodOfPerformanceReport < BaseReport
    REPORT_NAME = 'sp-active-users-over-period-of-performance-report'.freeze

    def perform(_date)
      results = transaction_with_timeout do
        Db::Identity::SpActiveUserCountsWithinIaaWindow.call
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end
  end
end
