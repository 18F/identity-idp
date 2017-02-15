module Idv
  class ProfileFromApplicant
    attr_reader :profile

    def self.create(applicant:, user:, normalized_applicant:)
      profile = Profile.new(user: user)
      plain_pii = pii_from_applicant(applicant, normalized_applicant)
      profile.encrypt_pii(user.user_access_key, plain_pii)
      profile.save!
      profile
    end

    # rubocop:disable MethodLength, AbcSize
    # This method is single statement spread across many lines for readability
    def self.pii_from_applicant(appl, norm_appl)
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
    private_class_method :pii_from_applicant
  end
end
