module Agreements
  class IaaIal2UsersQuery
    def self.call(**args)
      new(**args).call
    end

    def initialize(order:)
      @order = order
    end

    def call
      SpReturnLog.
        includes(service_provider: { integration: { integration_usages: :iaa_order } }).
        where(
          iaa_orders: { id: order.id },
          ial: 2,
          returned_at: order.start_date..order.end_date,
        ).
        distinct.
        count(:user_id)
    end

    private

    attr_reader :order
  end
end
