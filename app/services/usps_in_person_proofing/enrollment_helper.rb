# frozen_string_literal: true

module UspsInPersonProofing
  class EnrollmentHelper
    class << self
      # Creates a USPS enrollment using the USPS API. This also updates the user's
      # InPersonEnrollment to be pending.
      #
      # @param [User] user The user to create a USPS enrollment for
      # @param [Pii::UspsApplicant] applicant_pii The data used for creating the usps applicant.
      # @param [Boolean] is_enhanced_ipp Whether the enrollment is an EIPP enrollment.
      # @param [Boolean] opt_in Whether the user opted in to IPP.
      def schedule_in_person_enrollment(user:, applicant_pii:, is_enhanced_ipp:, opt_in: nil)
        enrollment = user.establishing_in_person_enrollment
        return unless enrollment

        enrollment_code = create_usps_enrollment(enrollment, applicant_pii, is_enhanced_ipp)
        return unless enrollment_code

        # update the enrollment to status pending
        enrollment.enrollment_code = enrollment_code
        enrollment.current_address_matches_id = applicant_pii.current_address_same_as_id
        enrollment.status = :pending
        enrollment.enrollment_established_at = Time.zone.now
        enrollment.save!

        analytics(user: user).usps_ippaas_enrollment_created(
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
          second_address_line_present: applicant_pii.address_line2_present?,
          service_provider: enrollment.service_provider&.issuer,
          opted_in_to_in_person_proofing: opt_in,
          tmx_status: enrollment.profile&.tmx_status,
          enhanced_ipp: enrollment.enhanced_ipp?,
        )

        send_ready_to_verify_email(user, enrollment)
      end

      def cancel_stale_establishing_enrollments_for_user(user)
        user
          .in_person_enrollments
          .where(status: :establishing)
          .find_each(&:cancelled!)
      end

      # Cancel a user's associated establishing, pending, and in_fraud_review in-person enrollments.
      #
      # @param user [User] The user model
      def cancel_establishing_and_in_progress_enrollments(user)
        user
          .in_person_enrollments
          .where(status:
            [InPersonEnrollment::STATUS_ESTABLISHING] +
            InPersonEnrollment::IN_PROGRESS_ENROLLMENT_STATUSES.to_a)
          .find_each(&:cancel)
      end

      def usps_proofer
        if IdentityConfig.store.usps_mock_fallback
          UspsInPersonProofing::Mock::Proofer.new
        else
          UspsInPersonProofing::Proofer.new
        end
      end

      def localized_location(location)
        {
          address: location.address,
          city: location.city,
          distance: location.distance,
          name: location.name,
          saturday_hours: EnrollmentHelper.localized_hours(location.saturday_hours),
          state: location.state,
          sunday_hours: EnrollmentHelper.localized_hours(location.sunday_hours),
          weekday_hours: EnrollmentHelper.localized_hours(location.weekday_hours),
          zip_code_4: location.zip_code_4,
          zip_code_5: location.zip_code_5,
        }
      end

      def localized_hours(hours)
        return nil if hours.nil?

        if hours == 'Closed'
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed')
        elsif hours.include?(' - ') # Hyphen
          hours
            .split(' - ') # Hyphen
            .map { |time| Time.zone.parse(time).strftime(I18n.t('time.formats.event_time')) }
            .join(' – ') # Endash
        elsif hours.include?(' – ') # Endash
          hours
            .split(' – ') # Endash
            .map { |time| Time.zone.parse(time).strftime(I18n.t('time.formats.event_time')) }
            .join(' – ') # Endash
        else
          hours
        end
      end

      private

      def handle_bad_request_error(err, enrollment)
        message = err.response.dig(:body, 'responseMessage') || err.message
        raise Exception::RequestEnrollException.new(message, err, enrollment.id)
      end

      def handle_standard_error(err, enrollment)
        raise Exception::RequestEnrollException.new(err.message, err, enrollment.id)
      end

      def analytics(user: AnonymousUser.new)
        Analytics.new(user: user, request: nil, session: {}, sp: nil)
      end

      def create_usps_enrollment(enrollment, applicant_pii, is_enhanced_ipp)
        applicant = create_enrollment_applicant(applicant_pii, enrollment)
        response = usps_proofer.request_enroll(applicant, is_enhanced_ipp)

        response.enrollment_code
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
      rescue StandardError => err
        handle_standard_error(err, enrollment)
      end

      def create_enrollment_applicant(applicant, enrollment)
        UspsInPersonProofing::Applicant.from_usps_applicant_and_enrollment(applicant, enrollment)
      end

      def send_ready_to_verify_email(user, enrollment)
        user.confirmed_email_addresses.each do |email_address|
          UserMailer
            .with(user: user, email_address: email_address)
            .in_person_ready_to_verify(enrollment:)
            .deliver_now_or_later
        end
      end
    end
  end
end
