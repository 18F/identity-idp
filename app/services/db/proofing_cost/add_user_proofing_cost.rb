module Db
  module ProofingCost
    class AddUserProofingCost
      class ProofingCostTypeError < StandardError; end

      TOKEN_ALLOWLIST = %i[
        acuant_front_image
        acuant_back_image
        acuant_result
        acuant_selfie
        aamva
        lexis_nexis_resolution
        lexis_nexis_address
        gpo_letter
        phone_otp
      ].freeze

      def self.call(user_id, token)
        return unless user_id
        proofing_cost = ::ProofingCost.create_or_find_by(user_id: user_id)
        unless TOKEN_ALLOWLIST.include?(token.to_sym)
          NewRelic::Agent.notice_error(ProofingCostTypeError.new(token.to_s))
          return
        end
        proofing_cost["#{token}_count"] ||= 0
        proofing_cost["#{token}_count"] += 1
        proofing_cost.save
      end
    end
  end
end
