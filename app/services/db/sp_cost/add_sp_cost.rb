module Db
  module SpCost
    class AddSpCost
      TOKEN_WHITELIST = %i[
        aamva
        acuant_front_image
        acuant_back_image
        acuant_result
        acuant_selfie
        authentication
        digest
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        phone_otp
        sms
        user_added
        voice
      ].freeze

      def self.call(issuer, ial, token)
        return if issuer.nil? || token.blank?
        unless TOKEN_WHITELIST.index(token.to_sym)
          NewRelic::Agent.notice_error("sp_cost type ignored: #{token}")
          return
        end
        sp = ServiceProvider.find_by(issuer: issuer)
        agency_id = sp ? sp.agency_id : 0
        ::SpCost.create(issuer: issuer, ial: ial, agency_id: agency_id.to_i, cost_type: token)
      end
    end
  end
end
