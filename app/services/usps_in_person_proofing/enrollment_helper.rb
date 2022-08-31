module UspsInPersonProofing
  class EnrollmentHelper
    class << self
      def schedule_in_person_enrollment(user, pii)
        enrollment = user.establishing_in_person_enrollment
        return unless enrollment

        enrollment.current_address_matches_id = pii['same_address_as_id']
        enrollment.save!

        enrollment_code = create_usps_enrollment(enrollment, pii)
        return unless enrollment_code

        # update the enrollment to status pending
        enrollment.enrollment_code = enrollment_code
        enrollment.status = :pending
        enrollment.enrollment_established_at = Time.zone.now
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

      def establishing_in_person_enrollment_for_user(user)
        enrollment = user.establishing_in_person_enrollment
        return enrollment if enrollment.present?

        InPersonEnrollment.create!(
          unique_id: InPersonEnrollment.generate_unique_id,
          user: user,
          profile: nil,
        )
      end

      def create_usps_enrollment(enrollment, pii)
        address = [pii['address1'], pii['address2']].select(&:present?).join(' ')
        applicant = UspsInPersonProofing::Applicant.new(
          {
            unique_id: enrollment.usps_unique_id,
            first_name: pii['first_name'],
            last_name: pii['last_name'],
            address: address,
            city: pii['city'],
            state: pii['state'],
            zip_code: pii['zipcode'],
            email: 'no-reply@login.gov',
          },
        )

        proofer = usps_proofer
        response = proofer.request_enroll(applicant)
        response.enrollment_code
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
      rescue StandardError => err
        handle_standard_error(err, enrollment)
      end

      def cancel_stale_establishing_enrollments_for_user(user)
        user.
          in_person_enrollments.
          where(status: :establishing).
          each(&:cancelled!)
      end

      private

      def usps_proofer
        if IdentityConfig.store.usps_mock_fallback
          UspsInPersonProofing::Mock::Proofer.new
        else
          UspsInPersonProofing::Proofer.new
        end
      end

      def handle_bad_request_error(err, enrollment)
        message = err.response.dig(:body, 'responseMessage') || err.message
        raise Exception::RequestEnrollException.new(message, err, enrollment.id)
      end

      def handle_standard_error(err, enrollment)
        raise Exception::RequestEnrollException.new(err.message, err, enrollment.id)
      end
    end
  end
end
