require 'identity/hostdata'

module Reports
  class SpSuccessRateReport < BaseReport
    REPORT_NAME = 'sp-success-rate-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::SpReturnLog.success_rate_by_sp
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end
  end
end
