# frozen_string_literal: true

module Idv
  ProfileLogging = Struct.new(:profile) do
    def as_json
      profile.slice(
        %i[
          id
          active
          idv_level
          created_at
          verified_at
          activated_at
          in_person_verification_pending_at
          gpo_verification_pending_at
          fraud_review_pending_at
          fraud_rejection_at
          fraud_pending_reason
          deactivation_reason
        ],
      ).compact
    end
  end
end
