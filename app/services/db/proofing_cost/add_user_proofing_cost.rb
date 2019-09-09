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
      ].freeze

      def self.call(user_id, token)
        return unless user_id
        proofing_cost = ::ProofingCost.find_or_create_by(user_id: user_id)
        return unless TOKEN_WHITELIST.index(token.to_sym)
        value = proofing_cost.send("#{token}_count".to_sym).to_i
        proofing_cost.send("#{token}_count=".to_sym, value + 1)
        proofing_cost.save
      end
    end
  end
end
