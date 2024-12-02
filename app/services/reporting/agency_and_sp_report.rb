# frozen_string_literal: true

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

      idv_sps_facial_match, idv_sps_legacy = idv_sps.partition do |sp|
        facial_match_issuers.include?(sp.issuer)
      end

      idv_agency_facial_match_ids = idv_sps_facial_match.map(&:agency_id)
      idv_facial_match_agencies, idv_legacy_agencies = idv_agencies.partition do |agency|
        idv_agency_facial_match_ids.include?(agency.id)
      end

      [
        ['', 'Number of apps (SPs)', 'Number of agencies and states'],
        ['Auth', auth_sps.count, auth_agencies.count],
        ['IDV (Legacy IDV)', idv_sps_legacy.count, idv_legacy_agencies.count],
        ['IDV (Facial matching)', idv_sps_facial_match.count, idv_facial_match_agencies.count],
        ['Total', auth_sps.count + idv_sps.count, auth_agencies.count + idv_agencies.count],
      ]
    rescue ActiveRecord::QueryCanceled => err
      [
        ['Error', 'Message'],
        [err.class.name, err.message],
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
      @active_agencies ||= Agency.joins(:partner_accounts).
        where(partner_accounts: {
          partner_account_status: Agreements::PartnerAccountStatus.find_by(name: 'active'),
          became_partner: ..report_date,
        }).
        distinct
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

    def facial_match_issuers
      @facial_match_issuers ||= Reports::BaseReport.transaction_with_timeout do
        Profile.active.verified.facial_match.
          where('verified_at <= ?', report_date.end_of_day).
          distinct.
          pluck(:initiating_service_provider_issuer)
      end
    end
  end
end
