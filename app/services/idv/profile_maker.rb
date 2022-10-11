module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, user_password:, initiating_issuer: nil)
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
      self.initiating_issuer = initiating_issuer
    end

    def save_profile(active:, deactivation_reason: nil)
      profile = Profile.new(
        user: user,
        active: false,
        deactivation_reason: deactivation_reason,
        initiating_issuer: initiating_issuer,
      )
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = current_proofing_components
      profile.save!
      profile.activate if active
      profile
    end

    private

    def current_proofing_components
      user.proofing_component&.as_json || {}
    end

    attr_accessor :user, :user_password, :phone_confirmed, :initiating_issuer
    attr_writer :pii_attributes
  end
end
