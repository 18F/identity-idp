module Reporting
  class AgencyAndSpReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def agency_and_sp_report
      idv_sps, auth_sps = service_providers.partition { |sp| sp.ial.present? && sp.ial >= 2 }
      idv_agency_ids = idv_sps.map(&:agency_id).uniq
      idv_agencies, auth_agencies = active_agencies.partition do |agency|
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

    def active_agencies
      @active_agencies ||= begin
        Agreements::PartnerAccountStatus.find_by(name: 'active').
          partner_accounts.
          includes(:agency).
          where('became_partner <= ?', report_date).
          map(&:agency).
          uniq
      end
    end

    def service_providers
      @service_providers ||= Reports::BaseReport.transaction_with_timeout do
        issuers = ServiceProviderIdentity.
          where('created_at <= ?', report_date).
          distinct.
          pluck(:service_provider)
        ServiceProvider.where(issuer: issuers).active.external
      end
    end
  end
end
