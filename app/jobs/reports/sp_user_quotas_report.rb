require 'identity/hostdata'

module Reports
  class SpUserQuotasReport < BaseReport
    REPORT_NAME = 'sp-user-quotas-report'.freeze

    def perform(_date)
      results = run_report_and_save_to_s3
      update_quota_limit_cache
      notify_if_any_sp_over_quota_limit
      results
    end

    private

    def run_report_and_save_to_s3
      @sp_user_quotas_list = transaction_with_timeout do
        Db::Identity::SpUserQuotas.call(fiscal_start_date)
      end
      save_report(REPORT_NAME, @sp_user_quotas_list.to_json, extension: 'json')
    end

    def update_quota_limit_cache
      Db::ServiceProviderQuotaLimit::UpdateFromReport.call(@sp_user_quotas_list)
    end

    def notify_if_any_sp_over_quota_limit
      Db::ServiceProviderQuotaLimit::NotifyIfAnySpOverQuotaLimit.call
    end
  end
end
