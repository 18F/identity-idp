module Reporting
  class AgencyAndSpReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def agency_and_sp_report
      idv_agency_ids = idv_sps.collect { |sp| sp.agency_id }.uniq

      # We define auth as "not IDV", can include ial: 1 and ial: nil
      auth_sp_count = ServiceProvider.active.count - idv_sps.count
      auth_agency_count = Agency.count - idv_agency_ids.count

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
          where('launch_date <= ?', report_date).
          select(:id, :agency_id).
          to_a
      end
    end
  end
end
