module Agreements
  module Db
    class IaasByAgency
      def self.call
        IaaGtc.
          includes(
            :iaa_status,
            partner_account: :agency,
            iaa_orders: %i[iaa_status integrations],
          ).
          group_by { |gtc| gtc.partner_account.agency.abbreviation }.
          transform_values do |gtcs|
            gtcs.map do |gtc|
              gtc.iaa_orders.map do |order|
                Iaa.new(gtc: gtc, order: order)
              end
            end.flatten
          end
      end
    end
  end
end
