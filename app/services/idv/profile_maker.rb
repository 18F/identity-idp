# frozen_string_literal: true

module Idv
  class ProfileMaker
    attr_reader :pii_attributes, :proofing_components

    def initialize(
      applicant:,
      user:,
      user_password:,
      initiating_service_provider: nil
    )
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
      self.initiating_service_provider = initiating_service_provider
    end

    def save_profile(
      fraud_pending_reason:,
      gpo_verification_needed:,
      in_person_verification_needed:,
      selfie_check_performed:,
      proofing_components:,
      deactivation_reason: nil
    )
      profile = Profile.new(user: user, active: false, deactivation_reason: deactivation_reason)
      profile.initiating_service_provider = initiating_service_provider
      profile.deactivate_for_in_person_verification if in_person_verification_needed
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = proofing_components
      profile.fraud_pending_reason = fraud_pending_reason

      profile.idv_level = set_idv_level(
        in_person_verification_needed: in_person_verification_needed,
        selfie_check_performed: selfie_check_performed,
      )

      profile.save!
      profile.deactivate_for_gpo_verification if gpo_verification_needed

      if fraud_pending_reason.present? && !gpo_verification_needed && !in_person_verification_needed
        profile.deactivate_for_fraud_review
      end

      user.reload
      profile
    end

    private

    def set_idv_level(in_person_verification_needed:, selfie_check_performed:)
      if in_person_verification_needed
        if IdentityConfig.store.in_person_proofing_enforce_tmx &&
           FeatureManagement.proofing_device_profiling_decisioning_enabled?
          :in_person
        else
          :legacy_in_person
        end
      elsif selfie_check_performed
        :unsupervised_with_selfie
      else
        :legacy_unsupervised
      end
    end

    attr_accessor(
      :user,
      :user_password,
      :phone_confirmed,
      :initiating_service_provider,
    )
    attr_writer :pii_attributes
  end
end
