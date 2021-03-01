module Db
  module SpCost
    class AddSpCost
      class SpCostTypeError < StandardError; end

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

      def self.call(issuer, ial, token, transaction_id: nil)
        return if token.blank?
        unless TOKEN_WHITELIST.include?(token.to_sym)
          NewRelic::Agent.notice_error(SpCostTypeError.new(token.to_s))
          return
        end
        agency_id = (issuer.present? && ServiceProvider.find_by(issuer: issuer)&.agency_id) || 0
        ::SpCost.create(
          issuer: issuer.to_s,
          ial: ial,
          agency_id: agency_id,
          cost_type: token,
          transaction_id: transaction_id,
        )
      end
    end
  end
end
