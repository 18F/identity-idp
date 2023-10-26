module Reporting
  class AgencyAndSpReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end
    def agency_and_sp_report
      # Calling this with a past launch_day may give surprising results,
      # since it looks only at "active: true" SPs.
      # Aside: We don't actually use sp.id, but it seems silly to not grab it.
      #idv_sps = idv_sps
      # We also don't actually do anything with this list except count it.
      idv_agency_ids = idv_sps.collect { |sp| sp.agency_id }.uniq # 27

      # We define auth as "not IDV", can include ial: 1 and ial: nil
      auth_sp_count = ServiceProvider.active.count - idv_sps.count # 422
      auth_agency_count = Agency.count - idv_agency_ids.count # 175

      [
        ['', 'Number of apps (SPs)', 'Number of agencies'],
        ['Auth', auth_sp_count, auth_agency_count],
        ['IDV', idv_sps.count, idv_agency_ids.count],
      ]
    end

    def agency_and_sp_emailable_report
      EmailableReport.new(
        title: 'App and Agency Counts',
        table: agency_and_sp_report,
        filename: 'agency_and_sp_counts',
      )
    end

    private

    def idv_sps
      @idv_sps ||= Reports::BaseReport.transaction_with_timeout do
        ServiceProvider.active.
        where(ial: 2).
        where("launch_date <= ?", report_date).
        select(:id, :agency_id).
        to_a # 47
      end
    end
  end
end
