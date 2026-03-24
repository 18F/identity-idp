# frozen_string_literal: true

module AnalyticsEvents
  module IdvEvents

    # @param [Boolean] success Whether form validation was successful
    # @param [Boolean] address_edited
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # User submitted an idv address
    def idv_address_submitted(
      success:,
      address_edited: nil,
      error_details: nil,
      **extra
    )
      track_event(
        'IdV: address submitted',
        success: success,
        address_edited: address_edited,
        error_details: error_details,
        **extra,
      )
    end

    # User visited idv address page
    def idv_address_visit(**extra)
      track_event('IdV: address visited', **extra)
    end

    # @param [String] step the step that the user was on when they clicked cancel
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user confirmed their choice to cancel going through IDV
    def idv_cancellation_confirmed(
      step:,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: cancellation confirmed',
        step: step,
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [String] step the step that the user was on when they clicked cancel
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [boolean,nil] cancelled_enrollment Whether the user's IPP enrollment has been canceled
    # @param [String,nil] enrollment_code IPP enrollment code
    # @param [Integer,nil] enrollment_id ID of the associated IPP enrollment record
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user chose to go back instead of cancel IDV
    def idv_cancellation_go_back(
      step:,
      proofing_components: nil,
      cancelled_enrollment: nil,
      enrollment_code: nil,
      enrollment_id: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: cancellation go back',
        step: step,
        proofing_components: proofing_components,
        cancelled_enrollment: cancelled_enrollment,
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [String] step the step that the user was on when they clicked cancel
    # @param [String] request_came_from the controller and action from the
    #   source such as "users/sessions#new"
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user clicked cancel during IDV (presented with an option to go back or confirm)
    def idv_cancellation_visited(
      step:,
      request_came_from:,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: cancellation visited',
        step: step,
        request_came_from: request_came_from,
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # The user checked or unchecked the "By checking this box..." checkbox on the idv agreement step.
    # (This is a frontend event.)
    # @param [Boolean] checked Whether the user checked the checkbox
    def idv_consent_checkbox_toggled(checked:, **extra)
      track_event(
        'IdV: consent checkbox toggled',
        checked: checked,
        **extra,
      )
    end

    # User submitted IDV password confirm page
    # @param [Boolean] success
    # @param [Boolean] fraud_review_pending
    # @param [Boolean] fraud_rejection
    # @param [String,nil] fraud_pending_reason The reason this profile is eligible for fraud review
    # @param [Boolean] gpo_verification_pending
    # @param [Boolean] in_person_verification_pending
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Integer,nil] proofing_workflow_time_in_seconds The time since starting proofing
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @identity.idp.previous_event_name  IdV: review info visited
    def idv_enter_password_submitted(
      success:,
      fraud_review_pending:,
      fraud_rejection:,
      fraud_pending_reason:,
      gpo_verification_pending:,
      in_person_verification_pending:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      deactivation_reason: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      proofing_workflow_time_in_seconds: nil,
      **extra
    )
      track_event(
        :idv_enter_password_submitted,
        success:,
        deactivation_reason:,
        fraud_review_pending:,
        fraud_pending_reason:,
        gpo_verification_pending:,
        in_person_verification_pending:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        opted_in_to_in_person_proofing:,
        fraud_rejection:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        proofing_workflow_time_in_seconds:,
        **extra,
      )
    end

    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String] address_verification_method The method (phone or gpo) being
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    #        used to verify the user's identity
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # User visited IDV password confirm page
    # @identity.idp.previous_event_name  IdV: review info visited
    def idv_enter_password_visited(
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      proofing_components: nil,
      address_verification_method: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        :idv_enter_password_visited,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        address_verification_method:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # User visited forgot password page
    def idv_forgot_password(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: forgot password visited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # User confirmed forgot password
    def idv_forgot_password_confirmed(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: forgot password confirmed',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # LexisNexis Instant Verify API was called with the following results
    # @param [Boolean] success Result from LexisNexis Instant Verify API call
    # @param [Hash] errors Result from resolution proofing
    # @param [String] exception Exception that occured during download or synchronizaiton
    # @param [Boolean] timed_out Whether the proofing request timed out
    # @param [String] transaction_id The vendor specific transaction ID for the proofing request
    # @param [String] reference
    # @param [Hash] reason_codes Socure internal reason codes for accept reject decision
    # @param [Boolean] can_pass_with_additional_verification Whether the PII could be verified if
    # another vendor verified certain attributes
    # @param [Array<String>] attributes_requiring_additional_verification Attributes that need to
    # be verified by another vendor
    # @param [Array<String>, nil] source_attribution List of sources that contributed to the
    # resolution proofing result
    # @param [String, nil] vendor_name Vendor used
    # @param [String] vendor_id ID of vendor
    # @param [String] vendor_workflow ID of workflow or configuration the vendor used for this
    # transaction
    # @param [Array[String], nil] verified_attributes The attributes verified during proofing
    def idv_instant_verify_results(
      success:,
      errors:,
      exception:,
      timed_out:,
      transaction_id:,
      reference:,
      reason_codes:,
      can_pass_with_additional_verification:,
      attributes_requiring_additional_verification:,
      source_attribution:,
      vendor_name:,
      vendor_id:,
      vendor_workflow:,
      verified_attributes:,
      **extra
    )
      track_event(
        :idv_instant_verify_results,
        success:,
        errors:,
        exception:,
        timed_out:,
        transaction_id:,
        reference:,
        reason_codes:,
        can_pass_with_additional_verification:,
        attributes_requiring_additional_verification:,
        source_attribution:,
        vendor_name:,
        vendor_id:,
        vendor_workflow:,
        verified_attributes:,
        **extra,
      )
    end

    # Tracks when user reaches verify errors due to being rejected due to fraud
    def idv_not_verified_visited(**extra)
      track_event('IdV: Not verified visited', **extra)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [String] phone_type Pinpoint phone classification type
    # @param [Array<String>] types Phonelib parsed phone types
    # @param [String] carrier Pinpoint detected phone carrier
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] area_code Area code of phone number
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user submitted their phone on the phone confirmation page
    def idv_phone_confirmation_form_submitted(
      success:,
      otp_delivery_preference:,
      phone_type:,
      types:,
      carrier:,
      country_code:,
      area_code:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      error_details: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation form',
        success:,
        error_details:,
        phone_type:,
        types:,
        carrier:,
        country_code:,
        area_code:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        otp_delivery_preference:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user was rate limited for submitting too many OTPs during the IDV phone step
    def idv_phone_confirmation_otp_rate_limit_attempts(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'Idv: Phone OTP attempts rate limited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user was locked out for hitting the phone OTP rate limit during IDV
    def idv_phone_confirmation_otp_rate_limit_locked_out(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'Idv: Phone OTP rate limited user',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user was rate limited for requesting too many OTPs during the IDV phone step
    def idv_phone_confirmation_otp_rate_limit_sends(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'Idv: Phone OTP sends rate limited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] area_code area code of phone number
    # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
    # @param [Hash] telephony_response Response from Telephony gem
    # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Hash, nil] ab_tests data for ongoing A/B tests
    # The user resent an OTP during the IDV phone step
    def idv_phone_confirmation_otp_resent(
      success:,
      otp_delivery_preference:,
      country_code:,
      area_code:,
      rate_limit_exceeded:,
      telephony_response:,
      phone_fingerprint:,
      error_details: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      ab_tests: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation otp resent',
        success:,
        error_details:,
        otp_delivery_preference:,
        country_code:,
        area_code:,
        rate_limit_exceeded:,
        telephony_response:,
        phone_fingerprint:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        ab_tests:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] area_code area code of phone number
    # @param [Boolean] rate_limit_exceeded whether or not the rate limit was exceeded by this attempt
    # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
    # @param [Hash] telephony_response Response from Telephony gem
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [:test, :pinpoint] adapter which adapter the OTP was delivered with
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The user requested an OTP to confirm their phone during the IDV phone step
    def idv_phone_confirmation_otp_sent(
      success:,
      otp_delivery_preference:,
      country_code:,
      area_code:,
      rate_limit_exceeded:,
      phone_fingerprint:,
      telephony_response:,
      adapter:,
      error_details: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation otp sent',
        success:,
        error_details:,
        otp_delivery_preference:,
        country_code:,
        area_code:,
        rate_limit_exceeded:,
        phone_fingerprint:,
        telephony_response:,
        adapter:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Boolean] code_expired if the one-time code expired
    # @param [Boolean] code_matches
    # @param ["sms", "voice"] otp_delivery_preference Channel used to send the message
    # @param [Integer] second_factor_attempts_count number of attempts to confirm this phone
    # @param [Time, nil] second_factor_locked_at timestamp when the phone was locked out
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # When a user attempts to confirm possession of a new phone number during the IDV process
    def idv_phone_confirmation_otp_submitted(
      success:,
      code_expired:,
      code_matches:,
      otp_delivery_preference:,
      second_factor_attempts_count:,
      second_factor_locked_at:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      error_details: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation otp submitted',
        success:,
        error_details:,
        code_expired:,
        code_matches:,
        otp_delivery_preference:,
        second_factor_attempts_count:,
        second_factor_locked_at:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # When a user visits the page to confirm posession of a new phone number during the IDV process
    def idv_phone_confirmation_otp_visit(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation otp visited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Hash,nil] proofing_components User's current proofing components
    # @param [Hash] vendor Vendor response payload
    # @param [Boolean] new_phone_added Whether phone number was added to account in submission
    # @param [Boolean] hybrid_handoff_phone_used Whether phone is the same as what was used for hybrid
    #   document capture
    # @param [String] area_code Area code of phone number
    # @param [String] country_code Abbreviated 2-letter country code associated with phone number
    # @param [String] phone_fingerprint HMAC fingerprint of the phone number formatted as E.164
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [String] customer_user_id user uuid sent to socure
    # @param [Hash] reason_codes socure internal reason codes for accept reject decision
    # @param [Hash] alternate_result Details for proofing attempt with primary vendor
    # @param [Boolean, nil] manual_review Phone was manually reviewed
    # The vendor finished the process of confirming the users phone
    def idv_phone_confirmation_vendor_submitted(
      success:,
      vendor:,
      area_code:,
      country_code:,
      phone_fingerprint:,
      new_phone_added:,
      hybrid_handoff_phone_used:,
      manual_review:,
      errors: nil,
      opted_in_to_in_person_proofing: nil,
      error_details: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      reason_codes: nil,
      customer_user_id: nil,
      alternate_result: nil,
      **extra
    )
      track_event(
        'IdV: phone confirmation vendor',
        success:,
        errors:,
        error_details:,
        vendor:,
        area_code:,
        country_code:,
        phone_fingerprint:,
        new_phone_added:,
        hybrid_handoff_phone_used:,
        manual_review:,
        opted_in_to_in_person_proofing:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        reason_codes:,
        customer_user_id:,
        alternate_result:,
        **extra,
      )
    end

    # @param ['warning','jobfail','failure'] type
    # @param [Time] limiter_expires_at when the rate limit expires
    # @param [Integer] remaining_submit_attempts number of submit attempts remaining
    #                  (previously called "remaining_attempts")
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # When a user gets an error during the phone finder flow of IDV
    def idv_phone_error_visited(
      type:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      proofing_components: nil,
      limiter_expires_at: nil,
      remaining_submit_attempts: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone error visited',
        type:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        proofing_components:,
        limiter_expires_at:,
        remaining_submit_attempts:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # User visited idv phone of record
    def idv_phone_of_record_visited(
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: phone of record visited',
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String] step the step the user was on when they clicked use a different phone number
    # User decided to use a different phone number in idv
    def idv_phone_use_different(step:, proofing_components: nil, **extra)
      track_event(
        'IdV: use different phone number',
        step: step,
        proofing_components: proofing_components,
        **extra,
      )
    end

    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # The system encountered an error and the proofing results are missing
    def idv_proofing_resolution_result_missing(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: proofing resolution result missing',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # Tracks when the user visits one of the the session error pages.
    # @param [String] type
    # @param [Integer,nil] remaining_submit_attempts
    #   (previously called "attempts_remaining" and "submit_attempts_remaining")
    def idv_session_error_visited(
      type:,
      remaining_submit_attempts: nil,
      **extra
    )
      track_event(
        'IdV: session error visited',
        type:,
        remaining_submit_attempts:,
        **extra,
      )
    end

    # @param [Boolean] success Whether the state ID validation was successful.
    # @param [String] vendor_name The name of the vendor doing the validation. If the ID was not from
    #   a supported jurisdiction, it will be "UnsupportedJurisdiction". It MAY also be
    #   "UnsupportedJurisdiction" if state ID verification was not needed because other vendor calls
    #   did not succeed.
    # @param [String] transaction_id The vendor specific transaction ID for the proofing request.
    # @param [Hash<String,Numeric>] requested_attributes The values sent in the proofing request.
    #   "1" represents that the value was sent.
    # @param [Array[String], nil] verified_attributes The attributes verified during proofing.
    # @param [Boolean] ipp_enrollment_in_progress Whether the user has entered the in-person proofing
    #   flow.
    # @param [Boolean] jurisdiction_in_maintenance_window Whether the target state MVA is under
    #   maintenance.
    # @param [Boolean] supported_jurisdiction Whether the state ID jurisdiction is supported by AAMVA.
    # @param [Boolean] timed_out Whether the proofing request timed out.
    # @param [Boolean] aamva_checked Whether the aamva API request evaluated a state ID.
    # @param [Integer, nil] birth_year The birth year listed on the ID.
    # @param [String, nil] state The state on the ID.
    # @param [String, nil] state_id_jurisdiction The state that issued the ID.
    # @param [String, nil] state_id_number A string describing the format of the ID number.
    # @param [Hash, nil] errors The errors encountered during proofing.
    # @param [String, nil] exception The exception message.
    # @param [Boolean, nil] mva_exception Whether an MVA exception occured.
    def idv_state_id_validation(
      success:,
      vendor_name:,
      transaction_id:,
      requested_attributes:,
      verified_attributes:,
      ipp_enrollment_in_progress:,
      jurisdiction_in_maintenance_window:,
      supported_jurisdiction:,
      timed_out:,
      aamva_checked:,
      birth_year: nil,
      state: nil,
      state_id_jurisdiction: nil,
      state_id_number: nil,
      errors: nil,
      exception: nil,
      mva_exception: nil,
      **extra
    )
      track_event(
        :idv_state_id_validation,
        success:,
        vendor_name:,
        transaction_id:,
        requested_attributes:,
        verified_attributes:,
        ipp_enrollment_in_progress:,
        jurisdiction_in_maintenance_window:,
        supported_jurisdiction:,
        timed_out:,
        aamva_checked:,
        birth_year:,
        state:,
        state_id_jurisdiction:,
        state_id_number:,
        errors:,
        exception:,
        mva_exception:,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] location
    # @param [Boolean] use_alternate_sdk
    def idv_warning_action_triggered(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      location:,
      use_alternate_sdk:,
      **extra
    )
      track_event(
        'Frontend: IdV: warning action triggered',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        location: location,
        use_alternate_sdk: use_alternate_sdk,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param [String] error_message_displayed
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] heading
    # @param [String] location
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param [String] subheading
    # @param [Boolean] use_alternate_sdk
    # @param [Boolean] liveness_checking_required
    def idv_warning_shown(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      error_message_displayed:,
      flow_path:,
      heading:,
      location:,
      remaining_submit_attempts:,
      subheading:,
      use_alternate_sdk:,
      liveness_checking_required:,
      **extra
    )
      track_event(
        'Frontend: IdV: warning shown',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        error_message_displayed: error_message_displayed,
        flow_path: flow_path,
        heading: heading,
        location: location,
        remaining_submit_attempts: remaining_submit_attempts,
        subheading: subheading,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Proofing Address Timeout
    # The job for address verification (PhoneFinder) did not record a result in the expected
    # place during the expected time frame
    def proofing_address_result_missing
      track_event('Proofing Address Result Missing')
    end
  end
end
