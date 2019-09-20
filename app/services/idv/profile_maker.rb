module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, user_password:)
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.user_password = user_password
    end

    def save_profile
      profile = Profile.new(
        deactivation_reason: :verification_pending,
        user: user,
      )
      profile.encrypt_pii(pii_attributes, user_password)
      profile.proofing_components = current_proofing_components_to_json
      profile.save!
      profile
    end

    private

    def current_proofing_components_to_json
      proofing_component = ProofingComponent.find_by(user_id: user.id)
      (proofing_component ? proofing_component : {}).to_json
    end

    attr_accessor :user, :user_password, :phone_confirmed
    attr_writer :pii_attributes
  end
end
