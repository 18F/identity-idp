module Agreements
  class IaaUsage
    attr_reader :authentications, :ial2_users

    def initialize(order:)
      @order = order
      @issuers = order.integrations.pluck(:issuer)
      @authentications = Hash.new(0)
      @ial2_users = Set.new
    end

    # return self so that it can be used in #tranform_values!
    def count(return_log)
      issuer = return_log.issuer
      return self unless issuers.include?(issuer) && order.in_pop?(return_log.returned_at)

      @authentications[issuer] += 1

      return self unless return_log.ial == 2

      @ial2_users.add(return_log.user_id)

      self
    end

    private

    attr_reader :order, :issuers
  end
end
