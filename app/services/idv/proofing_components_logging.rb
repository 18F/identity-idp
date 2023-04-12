module Idv
  ProofingComponentsLogging = Struct.new(:proofing_components) do
    def as_json(*)
      proofing_components.slice(
        :document_check,
        :document_type,
        :source_check,
        :resolution_check,
        :address_check,
        :liveness_check,
        :device_fingerprinting_vendor,
        :threatmetrix,
        :threatmetrix_review_status,
        :threatmetrix_risk_rating,
        :threatmetrix_policy_score,
      ).compact
    end
  end
end
