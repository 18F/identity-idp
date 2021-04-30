module Agreements
  class IaaAuthsQuery
    def self.call(**args)
      new(**args).call
    end

    def initialize(order:)
      @order = order
    end

    def call
      count = 0

      SpReturnLog.
        select(:id, :issuer, :returned_at).
        find_in_batches(batch_size: 10_000) do |batch|
          batch.each do |return_log|
            if issuers_from_order.include?(return_log.issuer) &&
               order.in_pop?(return_log.returned_at)
              count += 1
            end
          end
        end

      count
    end

    private

    attr_reader :order

    def issuers_from_order
      @issuers_from_order ||= Integration.
        includes(integration_usages: :iaa_order).
        where(iaa_orders: { id: order.id }).
        distinct.
        pluck(:issuer)
    end
  end
end
