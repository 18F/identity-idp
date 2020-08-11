require 'login_gov/hostdata'

module Reports
  class IaaBillingReport < BaseReport
    REPORT_NAME = 'iaa-billing-report'.freeze

    def call
      ret = []
      results = transaction_with_timeout do
        unique_iaa_sps.each do |sp|
          count = Db::Identity::IaaActiveUserCount.new(
            sp.iaa,
            sp.iaa_start_date,
            sp.iaa_end_date,
          ).call(2, Time.zone.today)
          ret << { service_provider: sp.to_json, ial2_count: count }
        end
      end
      save_report(REPORT_NAME, results.to_json)
    end

    private

    def unique_iaa_sps
      iaa_done = {}
      sps = []
      ServiceProvider.where.not(iaa: nil).select('iaa', 'iaa_start_date', 'iaa_end_date', 'ial').
        each do |sp|
        iaa = sp.iaa
        next if sp.ial == 1 || iaa_done[iaa]
        sps << sp
        iaa_done[iaa] = true
      end
      sps
    end
  end
end
