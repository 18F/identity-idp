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
      IaaReportingHelper.key(gtc_number:, order_number:)
    end
  end

  PartnerConfig = Struct.new(
    :partner,
    :issuers,
    :start_date,
    :end_date,
    keyword_init: true,
  )

  # @return [Array<IaaConfig>]
  def iaas
    Agreements::IaaGtc
      .includes(iaa_orders: { integration_usages: :integration })
      .flat_map do |gtc|
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
    Agreements::PartnerAccount
      .includes(integrations: { service_provider: {}, integration_usages: :iaa_order })
      .flat_map do |partner_account|
        issuers = partner_account.integrations.map do |integration|
          integration.service_provider.issuer
        end
        iaa_start_dates = partner_account.integrations.flat_map do |integration|
          integration.integration_usages.flat_map do |usage|
            usage.iaa_order.start_date
          end
        end
        iaa_end_dates = partner_account.integrations.flat_map do |integration|
          integration.integration_usages.flat_map do |usage|
            usage.iaa_order.end_date
          end
        end

        if issuers.present?
          PartnerConfig.new(
            partner: partner_account.requesting_agency,
            issuers: issuers.sort,
            start_date: iaa_start_dates.min,
            end_date: iaa_end_dates.max,
          )
        end
      end.compact
  end

  def key(gtc_number:, order_number:)
    "#{gtc_number}-#{format('%04d', order_number)}"
  end
end
