module Agreements
  module Reports
    class PartnerAccountsReport < BaseReport
      REPORT_NAME = 'partner_accounts'
      ENDPOINT_PATH = 'agencies/'

      def call
        partner_accounts = transaction_with_timeout do
          PartnerAccount.
            includes(:agency, :partner_account_status).
            group_by { |pa| pa.agency.abbreviation }
        end

        partner_accounts.each do |agency_abbr, accounts|
          save_report(
            REPORT_NAME,
            PartnerAccountBlueprint.render(accounts),
            "#{ENDPOINT_PATH}#{agency_abbr}/",
          )
        end
      end
    end
  end
end
