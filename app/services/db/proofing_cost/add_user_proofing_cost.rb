module Db
  module ProofingCost
    class AddUserProofingCost
      TOKEN_WHITELIST = %i[
        acuant_front_image
        acuant_back_image
        aamva
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        phone_otp
      ].freeze

      def self.call(user_id, token)
        return unless user_id
        proofing_cost = ::ProofingCost.find_or_create_by(user_id: user_id)
        return unless TOKEN_WHITELIST.index(token.to_sym)
        proofing_cost["#{token}_count"] += 1
        proofing_cost.save
      end
    end
  end
end
