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
      idv_agencies, auth_agencies = Agency.all.partition { |ag| idv_agency_ids.include?(ag.id) }

      [
        ['', 'Number of apps (SPs)', 'Number of agencies'],
        ['Auth', auth_sps.count, auth_agencies.count],
        ['IDV', idv_sps.count, idv_agencies.count],
      ]
    end

    def agency_and_sp_emailable_report
      EmailableReport.new(
        title: 'App and Agency Counts',
        table: agency_and_sp_report,
        filename: 'agency_and_sp_counts',
      )
    end
  end
end
