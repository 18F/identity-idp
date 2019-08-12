require 'login_gov/hostdata'

module Reports
  class AgencyUserCountsReport < BaseReport
    REPORT_NAME = 'agency-user-counts-report'.freeze

    def call
      user_counts = transaction_with_timeout do
        Db::AgencyIdentity::AgencyUserCounts.call
      end
      save_report(REPORT_NAME, user_counts.to_json)
    end
  end
end
