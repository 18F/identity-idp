# Abstract class to combine IaaGtcs and IaaOrders for JSON serialization
module Agreements
  class Iaa
    include ActiveModel::Model

    attr_accessor :gtc, :order
    attr_writer :ial2_users, :authentications

    delegate :gtc_number, to: :gtc
    delegate :order_number, to: :order
    delegate :mod_number,
             :start_date,
             :end_date,
             :estimated_amount,
             :status,
             to: :gtc,
             prefix: true
    delegate :mod_number,
             :start_date,
             :end_date,
             :estimated_amount,
             :status,
             to: :order,
             prefix: true

    def ial2_users
      @ial2_users || 0
    end

    def authentications
      @authentications || {}
    end

    def iaa_number
      "#{gtc.gtc_number}-#{'%04d' % order.order_number}-#{'%04d' % order.mod_number}"
    end

    def partner_account
      gtc.partner_account.requesting_agency
    end

    def ==(other)
      other.gtc == gtc && other.order == order
    end
  end
end
