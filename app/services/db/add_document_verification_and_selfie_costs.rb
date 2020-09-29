module Db
  class AddDocumentVerificationAndSelfieCosts
    def initialize(user_id:, issuer:, liveness_checking_enabled:)
      @issuer = issuer
      @liveness_checking_enabled = liveness_checking_enabled
      @user_id = user_id
    end

    def call(client_response)
      add_cost(:acuant_front_image)
      add_cost(:acuant_back_image)
      add_cost(:acuant_selfie) if liveness_checking_enabled
      add_cost(:acuant_result) if client_response.to_h[:billed]
    end

    private

    attr_reader :issuer, :liveness_checking_enabled, :user_id

    def add_cost(token)
      Db::SpCost::AddSpCost.call(issuer, 2, token)
      Db::ProofingCost::AddUserProofingCost.call(user_id, token)
    end
  end
end
