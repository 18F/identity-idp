module Db
  module SpCost
    class AddSpCost
      TOKEN_WHITELIST = %i[
        acuant_front_image
        acuant_back_image
        aamva
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        phone_otp
        sms
      ].freeze

      def self.call(issuer, agency_id, token)
        return if issuer.blank? || agency_id.blank? || token.blank?
        return unless TOKEN_WHITELIST.index(token.to_sym)
        ::SpCost.create(issuer: issuer, agency_id: agency_id, cost_type: token)
      end
    end
  end
end
