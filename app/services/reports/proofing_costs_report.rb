require 'login_gov/hostdata'

module Reports
  class ProofingCostsReport < BaseReport
    REPORT_NAME = 'proofing-costs-report'.freeze

    def call
      report = transaction_with_timeout do
        Db::ProofingCost::ProofingCostsSummary.new.call
      end
      save_report(REPORT_NAME, report.to_json)
    end
  end
end
