module Agreements
  module Db
    class AccountsByAgency
      def self.call
        PartnerAccount.
          includes(:agency, :partner_account_status).
          group_by { |pa| pa.agency }
      end
    end
  end
end
