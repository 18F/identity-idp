module Agreements
  module Reports
    class PartnerApiReport
      def run
        return unless IdentityConfig.store.enable_partner_api

        collect_account_data
        upload_json_files
        true
      end

      private

      attr_reader :accounts_by_agency, :agencies

      def collect_account_data
        @accounts_by_agency = Agreements::Db::AccountsByAgency.call
        @agencies = accounts_by_agency.keys
        @accounts_by_agency = accounts_by_agency.transform_keys(&:abbreviation)
      end

      def upload_json_files
        upload_agencies
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
    end
  end
end
