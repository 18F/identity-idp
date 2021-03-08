require 'identity/hostdata'

module Reports
  class SpActiveUsersReport < BaseReport
    REPORT_NAME = 'sp-active-users-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.call(fiscal_start_date)
      end
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
