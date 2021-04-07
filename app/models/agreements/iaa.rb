# Abstract class to combine IaaGtcs and IaaOrders for JSON serialization
module Agreements
  class Iaa
    include ActiveModel::Model

    attr_accessor :gtc, :order, :auths, :ial2_users

    delegate :gtc_number, to: :gtc
    delegate :order_number, to: :order

    def iaa_number
      "#{gtc.gtc_number}-#{'%04d' % order.order_number}-#{'%04d' % order.mod_number}"
    end

    def partner_account
      gtc.partner_account.requesting_agency
    end

    def gtc_status
      gtc.partner_status
    end

    def order_status
      order.partner_status
    end

    def method_missing(method)
      match = METHOD_REGEX.match(method)

      return super if match.nil?

      send(match[:obj]).public_send(match[:method])
    end

    private

    METHOD_REGEX = /\A(?<obj>gtc|order)_(?<method>.+)\z/
  end
end
