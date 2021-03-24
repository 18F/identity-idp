module Agreements
  module Reports
    class AgenciesReport < BaseReport
      REPORT_NAME = 'agencies'
      ENDPOINT_PATH = ''

      def call(status = 'active')
        agencies = transaction_with_timeout do
          Agency.
            select(:name, :abbreviation).
            includes(partner_accounts: :partner_account_status).
            where(partner_account_statuses: { name: status }).
            where.not(partner_accounts: { id: nil }).
            order('agencies.name').
            distinct
        end

        save_report(REPORT_NAME, agencies.to_json(except: :id), ENDPOINT_PATH)
      end
    end
  end
end
