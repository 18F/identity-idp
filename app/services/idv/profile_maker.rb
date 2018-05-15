module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, phone_confirmed:)
      self.pii_attributes = Pii::Attributes.new_from_hash(applicant)
      self.user = user
      self.phone_confirmed = phone_confirmed
    end

    def save_profile
      profile = Profile.new(
        deactivation_reason: :verification_pending,
        phone_confirmed: phone_confirmed,
        user: user
      )
      profile.encrypt_pii(user.user_access_key, pii_attributes)
      profile.save!
      profile
    end

    private

    attr_accessor :user, :phone_confirmed
    attr_writer :pii_attributes
  end
end
