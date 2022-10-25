require 'identity/hostdata'

module Reports
  class IaaBillingReport < BaseReport
    REPORT_NAME = 'iaa-billing-report'.freeze

    def perform(_today)
      @sps_for_iaa = {}
      @today = Time.zone.today
      results = []
      transaction_with_timeout do
        unique_iaa_sps.each do |sp|
          iaa_results = active_ial2_counts_for_iaa(sp)
          auth_counts = auth_counts_for_iaa(sp.iaa)
          iaa_results['auth_counts'] = auth_counts
          results << iaa_results
        end
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    private

    attr_accessor :today, :sps_for_iaa

    def auth_counts_for_iaa(iaa)
      results = []
      sps_for_iaa[iaa].each do |sp|
        results << sp_month_auth_counts(sp, 1)
        results << sp_month_auth_counts(sp, 2)
      end
      results
    end

    def sp_month_auth_counts(sp, ial)
      count = Db::MonthlySpAuthCount::SpMonthTotalAuthCounts.call(today, sp.issuer, ial)
      { issuer: sp.issuer, ial: ial, count: count }.stringify_keys
    end

    def active_ial2_counts_for_iaa(sp)
      count = Db::Identity::IaaActiveUserCount.new(
        sp.iaa,
        sp.iaa_start_date,
        sp.iaa_end_date,
      ).call(2, today)
      { iaa: sp.iaa,
        iaa_start_date: sp.iaa_start_date.strftime('%Y-%m-%d'),
        iaa_end_date: sp.iaa_end_date.strftime('%Y-%m-%d'),
        ial2_active_count: count }.stringify_keys
    end

    def unique_iaa_sps
      iaa_done = {}
      sps = []
      ServiceProvider.where.not(
        iaa: nil,
      ).where.not(
        iaa_start_date: nil,
      ).where.not(
        iaa_end_date: nil,
      ).sort_by(&:issuer).each do |sp|
        iaa = sp.iaa
        (sps_for_iaa[iaa] ||= []) << sp
        next if iaa_done[iaa]
        sps << sp
        iaa_done[iaa] = true
      end
      sps
    end
  end
end
