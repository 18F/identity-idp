module Idv
  class ProfileFromApplicant
    attr_reader :profile

    def self.create(applicant, user)
      profile = Profile.new(user: user)
      plain_pii = pii_from_applicant(applicant)
      profile.encrypt_pii(user.user_access_key, plain_pii)
      profile.save!
      profile
    end

    # rubocop:disable MethodLength
    # This method is single statement spread across many lines for readability
    def self.pii_from_applicant(applicant)
      Pii::Attributes.new_from_hash(
        first_name: applicant.first_name,
        middle_name: applicant.middle_name,
        last_name: applicant.last_name,
        address1: applicant.address1,
        address2: applicant.address2,
        city: applicant.city,
        state: applicant.state,
        zipcode: applicant.zipcode,
        dob: applicant.dob,
        ssn: applicant.ssn,
        phone: applicant.phone
      )
    end
    # rubocop:enable MethodLength
    private_class_method :pii_from_applicant
  end
end
