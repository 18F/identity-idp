module Agreements
  module Reports
    class PartnerApiReport
      def run
        return unless IdentityConfig.store.enable_partner_api

        collect_account_data
        collect_iaa_data
        upload_json_files
        true
      end

      private

      attr_reader :accounts_by_agency, :agencies, :iaas_by_agency

      def collect_account_data
        @accounts_by_agency = Agreements::Db::AccountsByAgency.call
        @agencies = accounts_by_agency.keys
        @accounts_by_agency = accounts_by_agency.transform_keys(&:abbreviation)
      end

      def collect_iaa_data
        @iaas_by_agency = Agreements::Db::IaasByAgency.call
      end

      def upload_json_files
        upload_agencies
        upload_iaas
        upload_accounts
      end

      def upload_agencies
        AgenciesReport.new(agencies: agencies).run
      end

      def upload_accounts
        accounts_by_agency.each do |agency_abbr, accounts|
          AgencyPartnerAccountsReport.new(agency: agency_abbr, partner_accounts: accounts).run
        end
      end

      def upload_iaas
        iaas_by_agency.each do |agency_abbr, iaas|
          AgencyIaasReport.new(agency: agency_abbr, iaas: iaas).run
        end
      end
    end
  end
end
