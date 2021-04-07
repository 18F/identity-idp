module Agreements
  module Reports
    class AgencyAgreementsReport < BaseReport
      REPORT_NAME = 'agreements'
      ENDPOINT_PATH = 'agencies/'

      def call
        agreements = transaction_with_timeout do
          IaaGtc.
            includes(:iaa_status, partner_account: :agency, iaa_orders: :iaa_status).
            group_by { |gtc| gtc.partner_account.agency.abbreviation }.
            transform_values do |gtcs|
              gtcs.map do |gtc|
                gtc.iaa_orders.map do |order|
                  auths = IaaAuthsQuery.call(order: order)
                  ial2_users = IaaIal2UsersQuery.call(order: order)
                  Iaa.new(gtc: gtc, order: order, auths: auths, ial2_users: ial2_users)
                end
              end.flatten
            end
        end

        agreements.each do |agency_abbr, iaas|
          save_report(
            REPORT_NAME,
            IaaBlueprint.render(iaas),
            "#{ENDPOINT_PATH}#{agency_abbr}/",
          )
        end
      end
    end
  end
end
