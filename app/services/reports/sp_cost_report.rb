require 'login_gov/hostdata'

module Reports
  class SpCostReport < BaseReport
    REPORT_NAME = 'sp-cost-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::SpCost::SpCostSummary.call
      end
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
