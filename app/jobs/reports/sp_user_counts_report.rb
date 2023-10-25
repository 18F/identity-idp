# frozen_string_literal: true

require 'identity/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'

    def perform(_date)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.by_issuer + Db::Identity::SpUserCounts.overall
      end

      save_report(REPORT_NAME, user_counts.to_json, extension: 'json')
    end
  end
end
