require 'login_gov/hostdata'

module Reports
  class IaaBillingReport < BaseReport
    REPORT_NAME = 'iaa-billing-report'.freeze

    def call
      results = []
      transaction_with_timeout do
        unique_iaa_sps.each { |sp| results << iaa_results(sp) }
      end
      save_report(REPORT_NAME, results.to_json)
    end

    private

    def iaa_results(sp)
      count = Db::Identity::IaaActiveUserCount.new(
        sp.iaa,
        sp.iaa_start_date,
        sp.iaa_end_date,
      ).call(2, Time.zone.today)
      { iaa: sp.iaa,
        iaa_start_date: sp.iaa_start_date.strftime('%Y-%m-%d'),
        iaa_end_date: sp.iaa_end_date.strftime('%Y-%m-%d'),
        ial2_active_count: count }.stringify_keys
    end

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
