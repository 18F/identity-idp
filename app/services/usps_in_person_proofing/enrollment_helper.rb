module UspsInPersonProofing
  class EnrollmentHelper
    def save_in_person_enrollment(user, profile, pii, selected_location_details = nil)
      enrollment = InPersonEnrollment.create!(
        profile: profile,
        user: user,
        current_address_matches_id: pii['same_address_as_id'],
        selected_location_details: selected_location_details,
      )

      enrollment_code = create_usps_enrollment(enrollment, pii)
      return unless enrollment_code

      # update the enrollment to status pending
      enrollment.enrollment_code = enrollment_code
      enrollment.status = :pending
      enrollment.save!

      send_ready_to_verify_email(user, pii, enrollment)
    end

    def send_ready_to_verify_email(user, pii, enrollment)
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.in_person_ready_to_verify(
          user,
          email_address,
          first_name: pii['first_name'],
          enrollment: enrollment,
        ).deliver_now_or_later
      end
    end

    def usps_proofer
      if IdentityConfig.store.usps_mock_fallback
        UspsInPersonProofing::Mock::Proofer.new
      else
        UspsInPersonProofing::Proofer.new
      end
    end

    def create_usps_enrollment(enrollment, pii)
      applicant = UspsInPersonProofing::Applicant.new(
        {
          unique_id: enrollment.usps_unique_id,
          first_name: pii['first_name'],
          last_name: pii['last_name'],
          address: pii['address1'],
          # do we need address2?
          city: pii['city'],
          state: pii['state'],
          zip_code: pii['zipcode'],
          email: 'no-reply@login.gov',
        },
      )
      proofer = usps_proofer

      response = proofer.request_enroll(applicant)
      response['enrollmentCode']
    end
  end
end
