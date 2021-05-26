require 'identity/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'.freeze

    def call
      user_counts = transaction_with_timeout { Db::Identity::SpUserCounts.call }
      save_report(REPORT_NAME, user_counts.to_json)
    end
  end
end
