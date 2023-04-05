require 'identity/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'.freeze

    def perform(_date)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.call
      end

      results = save_report(REPORT_NAME, user_counts.to_json, extension: 'json')

      results
    end
  end
end
