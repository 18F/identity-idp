module Agreements
  module Reports
    class AgencyPartnerAccountsReport < BaseReport
      def initialize(agency:, partner_accounts:)
        @agency = agency
        @partner_accounts = partner_accounts.sort_by(&:requesting_agency)
      end

      def run
        save_report(
          'partner_accounts',
          PartnerAccountBlueprint.render(partner_accounts, root: :partner_accounts),
        )
      end

      def report_path
        "agencies/#{agency.downcase}/"
      end

      private

      attr_reader :agency, :partner_accounts
    end
  end
end
