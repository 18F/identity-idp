# frozen_string_literal: true

module IaaReportingHelper
  module_function

  IaaConfig = Struct.new(
    :gtc_number,   # ex LG123567
    :order_number, # ex 1
    :issuers,
    :start_date,
    :end_date,
    keyword_init: true,
  ) do
    # ex LG123567-0001
    def key
      "#{gtc_number}-#{format('%04d', order_number)}"
    end
  end

  PartnerConfig = Struct.new(
    :partner_account_id,
    :partner_agency,
    :issuer,
    :start_date,
    :end_date,
    keyword_init: true,
  )

  # @return [Array<IaaConfig>]
  def iaas
    Agreements::IaaGtc.
      includes(iaa_orders: { integration_usages: :integration }).
      flat_map do |gtc|
        gtc.iaa_orders.flat_map do |iaa_order|
          issuers = iaa_order.integration_usages.map { |usage| usage.integration.issuer }

          if issuers.present?
            IaaConfig.new(
              gtc_number: gtc.gtc_number,
              order_number: iaa_order.order_number,
              issuers: issuers.sort,
              start_date: iaa_order.start_date,
              end_date: iaa_order.end_date,
            )
          end
        end.compact
      end.sort_by(&:key)
  end

  def partner_accounts
    Agreements::PartnerAccount.
      includes(integrations: :service_provider).
      flat_map do |partner_account|
        partner_account.integrations.map do |integration|
          sp_issuer = integration.service_provider.issuer
          if sp_issuer.present?
            PartnerConfig.new(
              partner_account_id: partner_account.id,
              partner_agency: partner_account.requesting_agency,
              issuer: sp_issuer,
              start_date: integration.service_provider.iaa_start_date,
              end_date: integration.service_provider.iaa_end_date,
            )
          end
        end.compact
      end.sort_by(&:partner_account_id)
  end
end
