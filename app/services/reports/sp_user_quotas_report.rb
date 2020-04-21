require 'login_gov/hostdata'

module Reports
  class SpUserQuotasReport < BaseReport
    REPORT_NAME = 'sp-user-quotas-report'.freeze

    def call
      results = transaction_with_timeout do
        Db::Identity::SpUserQuotas.call(fiscal_start_date)
      end
      Db::ServiceProviderQuota::UpdateFromReport.call(results)
      save_report(REPORT_NAME, results.to_json)
    end
  end
end
