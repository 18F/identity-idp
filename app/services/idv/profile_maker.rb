module Idv
  class ProfileMaker
    attr_reader :pii_attributes

    def initialize(applicant:, user:, normalized_applicant:, phone_confirmed:)
      self.pii_attributes = pii_from_applicant(
        OpenStruct.new(applicant),
        OpenStruct.new(normalized_applicant)
      )
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

    # rubocop:disable MethodLength, AbcSize
    # This method is single statement spread across many lines for readability
    def pii_from_applicant(appl, norm_appl)
      Pii::Attributes.new_from_hash(
        first_name: Pii::Attribute.new(raw: appl.first_name, norm: norm_appl.first_name),
        middle_name: Pii::Attribute.new(raw: appl.middle_name, norm: norm_appl.middle_name),
        last_name: Pii::Attribute.new(raw: appl.last_name, norm: norm_appl.last_name),
        address1: Pii::Attribute.new(raw: appl.address1, norm: norm_appl.address1),
        address2: Pii::Attribute.new(raw: appl.address2, norm: norm_appl.address2),
        city: Pii::Attribute.new(raw: appl.city, norm: norm_appl.city),
        state: Pii::Attribute.new(raw: appl.state, norm: norm_appl.state),
        zipcode: Pii::Attribute.new(raw: appl.zipcode, norm: norm_appl.zipcode),
        dob: Pii::Attribute.new(raw: appl.dob, norm: norm_appl.dob),
        ssn: Pii::Attribute.new(raw: appl.ssn, norm: norm_appl.ssn),
        phone: Pii::Attribute.new(raw: appl.phone, norm: norm_appl.phone)
      )
    end
    # rubocop:enable MethodLength, AbcSize
  end
end
