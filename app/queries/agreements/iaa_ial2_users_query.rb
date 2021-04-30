module Agreements
  class IaaIal2UsersQuery
    def self.call(**args)
      new(**args).call
    end

    def initialize(order:)
      @order = order
    end

    def call
      users = Set.new

      SpReturnLog.
        select(:id, :issuer, :returned_at, :ial, :user_id).
        find_in_batches(batch_size: 10_000) do |batch|
          batch.each do |return_log|
            if issuers_from_order.include?(return_log.issuer) &&
               order.in_pop?(return_log.returned_at) &&
               return_log.ial == 2 &&
               !users.include?(return_log.user_id)

              users << return_log.user_id
            end
          end
        end

      users.length
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
