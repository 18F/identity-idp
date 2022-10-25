require 'identity/hostdata'

module Reports
  class AgencyUserCountsReport < BaseReport
    REPORT_NAME = 'agency-user-counts-report'.freeze

    def perform(_date)
      user_counts = transaction_with_timeout do
        Db::AgencyIdentity::AgencyUserCounts.call
      end
      save_report(REPORT_NAME, user_counts.to_json, extension: 'json')
    end
  end
end
