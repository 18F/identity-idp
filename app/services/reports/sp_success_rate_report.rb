require 'login_gov/hostdata'

module Reports
  class SpSuccessRateReport < BaseReport
    REPORT_NAME = 'sp-success-rate-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::SpReturnLog::SuccessRateBySp.call
      end
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
