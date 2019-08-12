require 'login_gov/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'.freeze

    def call
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.call
      end
      save_report(REPORT_NAME, user_counts.to_json)
    end
  end
end
