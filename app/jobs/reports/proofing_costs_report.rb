require 'identity/hostdata'

module Reports
  class ProofingCostsReport < BaseReport
    REPORT_NAME = 'proofing-costs-report'.freeze

    def perform(_date)
      report = transaction_with_timeout do
        Db::ProofingCost::ProofingCostsSummary.new.call
      end
      save_report(REPORT_NAME, report.to_json, extension: 'json')
    end
  end
end
