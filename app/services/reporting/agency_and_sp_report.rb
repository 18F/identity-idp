module Reporting
  class AgencyAndSpReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def agency_and_sp_report
      idv_sps, auth_sps = ServiceProvider.where('created_at <= ?', report_date).active.
        partition { |sp| sp.ial.present? && sp.ial >= 2 }
      idv_agency_ids = idv_sps.map(&:agency_id).uniq
      idv_agencies, auth_agencies = agencies_with_sps.partition do |agency|
        idv_agency_ids.include?(agency.id)
      end

      [
        ['', 'Number of apps (SPs)', 'Number of agencies and states'],
        ['Auth', auth_sps.count, auth_agencies.count],
        ['IDV', idv_sps.count, idv_agencies.count],
        ['Total', auth_sps.count + idv_sps.count, auth_agencies.count + idv_agencies.count],
      ]
    end

    def agency_and_sp_emailable_report
      EmailableReport.new(
        title: 'App and Agency Counts',
        table: agency_and_sp_report,
        filename: 'agency_and_sp_counts',
      )
    end

    # Agencies have no timestamps, so we need to join to SPs to get something equivalent.
    def agencies_with_sps
      Agency.joins(:service_providers).
        where('service_providers.created_at <= ?', report_date).
        distinct
    end
  end
end
