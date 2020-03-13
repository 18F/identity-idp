require 'login_gov/hostdata'

module Reports
  class SpUserQuotasReport < BaseReport
    REPORT_NAME = 'sp-user-quotas-report'.freeze

    def call
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserQuotas.call(fiscal_start_date)
      end
      save_report(REPORT_NAME, user_counts.to_json)
    end
  end
end
