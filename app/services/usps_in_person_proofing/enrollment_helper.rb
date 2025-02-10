# frozen_string_literal: true

module UspsInPersonProofing
  class EnrollmentHelper
    class << self
      def schedule_in_person_enrollment(user:, pii:, is_enhanced_ipp:, opt_in: nil)
        enrollment = user.establishing_in_person_enrollment
        return unless enrollment

        enrollment.current_address_matches_id = pii['same_address_as_id']

        if enrollment.sponsor_id.nil?
          enrollment.sponsor_id = is_enhanced_ipp ?
            IdentityConfig.store.usps_eipp_sponsor_id :
            IdentityConfig.store.usps_ipp_sponsor_id
        end

        enrollment.save!

        # Send state ID address to USPS
        pii = pii.to_h
        if !enrollment.current_address_matches_id?
          pii = pii.except(*SECONDARY_ID_ADDRESS_MAP.values)
            .transform_keys(SECONDARY_ID_ADDRESS_MAP)
        end

        enrollment_code = create_usps_enrollment(enrollment, pii, is_enhanced_ipp)
        return unless enrollment_code

        # update the enrollment to status pending
        enrollment.enrollment_code = enrollment_code
        enrollment.status = :pending
        enrollment.enrollment_established_at = Time.zone.now
        enrollment.save!

        analytics(user: user).usps_ippaas_enrollment_created(
          enrollment_code: enrollment.enrollment_code,
          enrollment_id: enrollment.id,
          second_address_line_present: pii[:address2].present?,
          service_provider: enrollment.service_provider&.issuer,
          opted_in_to_in_person_proofing: opt_in,
          tmx_status: enrollment.profile&.tmx_status,
          enhanced_ipp: enrollment.enhanced_ipp?,
        )

        send_ready_to_verify_email(user, enrollment, is_enhanced_ipp: is_enhanced_ipp)
      end

      def send_ready_to_verify_email(user, enrollment, is_enhanced_ipp:)
        user.confirmed_email_addresses.each do |email_address|
          UserMailer.with(user: user, email_address: email_address).in_person_ready_to_verify(
            enrollment: enrollment,
            is_enhanced_ipp: is_enhanced_ipp,
          ).deliver_now_or_later
        end
      end

      # Create and start tracking an in-person enrollment with USPS
      #
      # @param [InPersonEnrollment] enrollment The new enrollment record for tracking the enrollment
      # @param [Pii::Attributes] pii The PII associated with the in-person enrollment
      # @return [String] The enrollment code
      # @raise [Exception::RequestEnrollException] Raised with a problem creating the enrollment
      def create_usps_enrollment(enrollment, pii, is_enhanced_ipp)
        applicant = UspsInPersonProofing::Applicant.new(
          {
            unique_id: enrollment.unique_id,
            first_name: transliterate(pii[:first_name]),
            last_name: transliterate(pii[:last_name]),
            address: transliterate(pii[:address1]),
            city: transliterate(pii[:city]),
            state: pii[:state],
            zip_code: pii[:zipcode],
            email: IdentityConfig.store.usps_ipp_enrollment_status_update_email_address.presence,
          },
        )

        proofer = usps_proofer
        response = proofer.request_enroll(applicant, is_enhanced_ipp)
        response.enrollment_code
      rescue Faraday::BadRequestError => err
        handle_bad_request_error(err, enrollment)
      rescue StandardError => err
        handle_standard_error(err, enrollment)
      end

      def cancel_stale_establishing_enrollments_for_user(user)
        user
          .in_person_enrollments
          .where(status: :establishing)
          .find_each(&:cancelled!)
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

      SECONDARY_ID_ADDRESS_MAP = {
        identity_doc_address1: :address1,
        identity_doc_address2: :address2,
        identity_doc_city: :city,
        identity_doc_address_state: :state,
        identity_doc_zipcode: :zipcode,
      }.freeze

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

      def transliterate(value)
        return value unless IdentityConfig.store.usps_ipp_transliteration_enabled

        result = transliterator.transliterate(value)
        if result.unsupported_chars.present?
          result.original
        else
          result.transliterated
        end
      end

      def transliterator
        Transliterator.new
      end
    end
  end
end
