require 'login_gov/hostdata'

module Reports
  class TotalSpCostReport < BaseReport
    REPORT_NAME = 'total-sp-cost-report'.freeze

    def call
      auth_counts = transaction_with_timeout do
        Db::SpCost::TotalSpCostSummary.call
      end
      save_report(REPORT_NAME, auth_counts.to_json)
    end
  end
end
