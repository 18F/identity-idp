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
              issuers: issuers,
              start_date: iaa_order.start_date,
              end_date: iaa_order.end_date,
            )
          end
        end.compact
      end
  end
end
