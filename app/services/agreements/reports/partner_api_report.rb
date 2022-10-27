module Agreements
  module Reports
    class PartnerApiReport < ApplicationJob
      queue_as :low

      def perform(_date)
        return unless IdentityConfig.store.enable_partner_api

        collect_account_data
        collect_iaa_data
        collect_usage_data
        upload_json_files
        true
      end

      private

      attr_reader :accounts_by_agency, :agencies, :iaas_by_agency, :usage_summary

      def collect_account_data
        @accounts_by_agency = Db::AccountsByAgency.call
        @agencies = accounts_by_agency.keys
        @accounts_by_agency = accounts_by_agency.transform_keys(&:abbreviation)
      end

      def collect_iaa_data
        @iaas_by_agency = Db::IaasByAgency.call
      end

      def collect_usage_data
        all_iaas = iaas_by_agency.values.flatten
        @usage_summary = UsageSummarizer.call(iaas: all_iaas)

        @iaas_by_agency.transform_values! do |iaas|
          iaas.each do |iaa|
            usage = usage_summary[:iaas][iaa.iaa_number]
            next if usage.blank?

            iaa.ial2_users = usage.ial2_users.size
            iaa.authentications = usage.authentications
          end
        end
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
