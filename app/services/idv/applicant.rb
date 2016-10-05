module Idv
  class Applicant
    attr_reader :profile

    def initialize(applicant, user, password)
      @profile = build_profile(applicant, user, password)
    end

    private

    # rubocop:disable MethodLength
    # This method is single statement spread across many lines for readability
    def pii_from_applicant(applicant)
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

    def build_profile(applicant, user, password)
      Profile.create_with_encrypted_pii(user, pii_from_applicant(applicant), password)
    end
  end
end
