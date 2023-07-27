module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(
      applicant:,
      user:,
      user_password:,
      initiating_service_provider: nil,
      in_person_verification_pending: false
    )
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
      self.initiating_service_provider = initiating_service_provider
      self.in_person_verification_pending = in_person_verification_pending
    end

    def save_profile(
      fraud_pending_reason:,
      gpo_verification_needed:,
      deactivation_reason: nil
    )
      profile = Profile.new(user: user, active: false, deactivation_reason: deactivation_reason)
      profile.initiating_service_provider = initiating_service_provider
      profile.deactivation_reason = :in_person_verification_pending if in_person_verification_pending
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = current_proofing_components
      profile.fraud_pending_reason = fraud_pending_reason
      profile.save!
      profile.deactivate_for_gpo_verification if gpo_verification_needed
      if fraud_pending_reason.present? && !gpo_verification_needed
        profile.deactivate_for_fraud_review
      end
      profile
    end

    private

    def current_proofing_components
      user.proofing_component&.as_json || {}
    end

    attr_accessor(
      :user,
      :user_password,
      :phone_confirmed,
      :initiating_service_provider,
      :in_person_verification_pending,
    )
    attr_writer :pii_attributes
  end
end
