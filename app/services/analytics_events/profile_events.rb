# frozen_string_literal: true

module AnalyticsEvents
  module ProfileEvents

    # User visited sign-in URL from the "You've been successfully verified email" CTA button
    # @param issuer [String] the ServiceProvider.issuer
    # @param campaign_id [String] the email campaign ID
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
    def idv_account_verified_cta_visited(
      issuer:,
      campaign_id:,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        :idv_account_verified_cta_visited,
        issuer:,
        campaign_id:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,

        **extra,
      )
    end

    # @param [Boolean] success
    # @param [String, nil] deactivation_reason Reason user's profile was deactivated, if any.
    # @param [Boolean] fraud_review_pending Profile is under review for fraud
    # @param [Boolean] fraud_rejection Profile is rejected due to fraud
    # @param [String,nil] fraud_pending_reason The reason this profile is eligible for fraud review
    # @param [Boolean] gpo_verification_pending Profile is awaiting gpo verification
    # @param [Boolean] in_person_verification_pending Profile is awaiting in person verification
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
    # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
    # @param [Integer,nil] proofing_workflow_time_in_seconds The time since starting proofing
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @see Reporting::IdentityVerificationReport#query This event is used by the identity verification
    #       report. Changes here should be reflected there.
    # Tracks the last step of IDV, indicates the user successfully proofed
    def idv_final(
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
      profile_history: nil,
      proofing_workflow_time_in_seconds: nil,
      **extra
    )
      track_event(
        'IdV: final resolution',
        success:,
        fraud_review_pending:,
        fraud_rejection:,
        fraud_pending_reason:,
        gpo_verification_pending:,
        in_person_verification_pending:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        deactivation_reason:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        profile_history:,
        proofing_workflow_time_in_seconds:,
        **extra,
      )
    end

    # User visits IdV
    # @param [Hash,nil] proofing_components User's proofing components.
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
    def idv_intro_visit(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      profile_history: nil,
      **extra
    )
      track_event(
        'IdV: intro visited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        profile_history: profile_history,
        **extra,
      )
    end

    # Tracks if a user clicks the 'acknowledge' checkbox during personal
    # key creation
    # @param [Hash,nil] proofing_components User's current proofing components
    # @option proofing_components [String,nil] 'document_check' Vendor that verified the user's ID
    # @option proofing_components [String,nil] 'document_type_received' Type of ID detected by vendor
    # @option proofing_components [String,nil] 'source_check' Source used to verify user's PII
    # @option proofing_components [String,nil] 'resolution_check' Vendor for identity resolution check
    # @option proofing_components [String,nil] 'address_check' Method used to verify user's address
    # @option proofing_components [Boolean,nil] 'threatmetrix' Whether ThreatMetrix check was done
    # @option proofing_components [String,nil] 'threatmetrix_review_status' TMX decision on the user
    # @param [boolean] checked whether the user checked or un-checked
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    #                  the box with this click
    def idv_personal_key_acknowledgment_toggled(
      checked:,
      proofing_components:,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: personal key acknowledgment toggled',
        checked: checked,
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # A user has downloaded their personal key. This event is no longer emitted.
    # @identity.idp.previous_event_name IdV: download personal key
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
    def idv_personal_key_downloaded(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: personal key downloaded',
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
    # @param [String, nil] deactivation_reason Reason profile was deactivated.
    # @param [Boolean] fraud_review_pending Profile is under review for fraud
    # @param [Boolean] fraud_rejection Profile is rejected due to fraud
    # @param [Boolean] in_person_verification_pending Profile is pending in-person verification
    # @param [String] address_verification_method "phone" or "gpo"
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # User submitted IDV personal key page
    def idv_personal_key_submitted(
      address_verification_method:,
      fraud_review_pending:,
      fraud_rejection:,
      in_person_verification_pending:,
      proofing_components: nil,
      deactivation_reason: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: personal key submitted',
        address_verification_method: address_verification_method,
        in_person_verification_pending: in_person_verification_pending,
        deactivation_reason: deactivation_reason,
        fraud_review_pending: fraud_review_pending,
        fraud_rejection: fraud_rejection,
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
    # @param [String] address_verification_method "phone" or "gpo"
    # @param [Boolean,nil] in_person_verification_pending
    # @param [Boolean] encrypted_profiles_missing True if user's session had no encrypted pii
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # User visited IDV personal key page
    def idv_personal_key_visited(
      opted_in_to_in_person_proofing: nil,
      proofing_components: nil,
      address_verification_method: nil,
      in_person_verification_pending: nil,
      encrypted_profiles_missing: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: personal key visited',
        opted_in_to_in_person_proofing:,
        proofing_components:,
        address_verification_method:,
        in_person_verification_pending:,
        encrypted_profiles_missing:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name IdV: Verify setup errors visited
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
    # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
    # Tracks when the user reaches the verify please call page after failing proofing
    def idv_please_call_visited(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      profile_history: nil,
      **extra
    )
      track_event(
        'IdV: Verify please call visited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        profile_history: profile_history,
        **extra,
      )
    end

    # @param [String] issuer the ServiceProvider.issuer
    # @param [String,nil] idv_level ID verification level of verified profile.
    # @param [String] verified_at The timestamp whenthe profile was verified
    # @param [String] activated_at The timestamp whenthe profile was activated
    def idv_profile_activated(
      idv_level:,
      verified_at:,
      activated_at:,
      issuer: nil,
      **extra
    )
      track_event(
        :idv_profile_activated,
        issuer:,
        idv_level:,
        verified_at:,
        activated_at:,
        **extra,
      )
    end

    # @param [String] step
    # @param [String] location
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
    # @param [Array,nil] profile_history Array of user's profiles (oldest to newest).
    # User started over idv
    def idv_start_over(
      step:,
      location:,
      cancelled_enrollment: nil,
      enrollment_code: nil,
      enrollment_id: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      profile_history: nil,
      **extra
    )
      track_event(
        'IdV: start over',
        step: step,
        location: location,
        proofing_components: proofing_components,
        cancelled_enrollment: cancelled_enrollment,
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        profile_history: profile_history,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Integer] emails Number of email addresses the notification was sent to
    # @param [Array<String>] sms_message_ids AWS Pinpoint SMS message IDs for each phone number that
    #   was notified
    # Alert user if a personal key was used to sign in
    def personal_key_alert_about_sign_in(
      success:,
      emails:,
      sms_message_ids:,
      error_details: nil,
      **extra
    )
      track_event(
        'Personal key: Alert user about sign in',
        success:,
        error_details:,
        emails:,
        sms_message_ids:,
        **extra,
      )
    end

    # Account reactivated with personal key
    def personal_key_reactivation
      track_event('Personal key reactivation: Account reactivated with personal key')
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # Personal key form submitted
    def personal_key_reactivation_submitted(
      success:,
      error_details: nil,
      **extra
    )
      track_event(
        'Personal key reactivation: Personal key form submitted',
        success:,
        error_details:,
        **extra,
      )
    end

    # Personal key reactivation visited
    def personal_key_reactivation_visited
      track_event('Personal key reactivation: Personal key form visited')
    end

    # @param [Boolean] personal_key_present if personal key is present
    # Personal key viewed
    def personal_key_viewed(personal_key_present:, **extra)
      track_event(
        'Personal key viewed',
        personal_key_present: personal_key_present,
        **extra,
      )
    end

    # @param [String] error
    # Tracks if a Profile encryption is invalid
    def profile_encryption_invalid(error:, **extra)
      track_event('Profile Encryption: Invalid', error: error, **extra)
    end

    # @see #profile_personal_key_create_notifications
    # User has chosen to receive a new personal key
    def profile_personal_key_create
      track_event('Profile: Created new personal key')
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Integer] emails Number of email addresses the notification was sent to
    # @param [Array<String>] sms_message_ids AWS Pinpoint SMS message IDs for each phone number that
    #   was notified
    # User has chosen to receive a new personal key, contains stats about notifications that
    # were sent to phone numbers and email addresses for the user
    def profile_personal_key_create_notifications(
      success:,
      emails:,
      sms_message_ids:,
      error_details: nil,
      **extra
    )
      track_event(
        'Profile: Created new personal key notifications',
        success:,
        error_details:,
        emails:,
        sms_message_ids:,
        **extra,
      )
    end

    # User has visited the page that lets them confirm if they want a new personal key
    def profile_personal_key_visit
      track_event('Profile: Visited new personal key')
    end
  end
end
