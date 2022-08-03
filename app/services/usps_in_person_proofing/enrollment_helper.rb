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

      # todo: don't need this anymore
      def create_usps_enrollment(enrollment, pii)
        address = pii['address1']
        address += " #{pii['address2']}" unless pii['address2'].blank?

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
        response = nil
        begin
          response = proofer.request_enroll(applicant)
        rescue Faraday::BadRequestError => err
          handle_bad_request_error(err, enrollment)
        rescue StandardError => err
          handle_standard_error(err, enrollment)
        end

        response&.enrollmentCode
      end

      def handle_bad_request_error(err, enrollment)
        analytics.idv_in_person_usps_request_enroll_exception(
          context: context,
          enrollment_id: enrollment.id,
          exception_class: err.class.to_s,
          exception_message: err.response.dig(:body, 'responseMessage') || err.message,
          reason: 'Request exception',
        )
      end

      def handle_standard_error(err, enrollment)
        analytics.idv_in_person_usps_request_enroll_exception(
          context: context,
          enrollment_id: enrollment.id,
          exception_class: err.class.to_s,
          exception_message: err.message,
          reason: 'Request exception',
        )
      end

      def establishing_in_person_enrollment_for_user(user)
        enrollment = user.establishing_in_person_enrollment
        return enrollment if enrollment.present?

        InPersonEnrollment.create!(user: user, profile: nil)
      end

      def usps_proofer
        if IdentityConfig.store.usps_mock_fallback
          UspsInPersonProofing::Mock::Proofer.new
        else
          UspsInPersonProofing::Proofer.new
        end
      end

      def cancel_stale_establishing_enrollments_for_user(user)
        user.
          in_person_enrollments.
          where(status: :establishing).
          each(&:cancelled!)
      end
    end
  end
end
