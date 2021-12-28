module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, user_password:, document_expired:)
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
      self.document_expired = document_expired
    end

    def save_profile
      profile = Profile.new(
        deactivation_reason: :verification_pending,
        user: user,
      )
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = current_proofing_components
      if document_expired
        profile.reproof_at = IdentityConfig.store.proofing_expired_license_reproof_at
      end
      profile.save!
      profile
    end

    private

    def current_proofing_components
      user.proofing_component&.as_json || {}
    end

    attr_accessor :user, :user_password, :phone_confirmed, :document_expired
    attr_writer :pii_attributes
  end
end
