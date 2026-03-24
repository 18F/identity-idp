# frozen_string_literal: true

module AnalyticsEvents
  module GpoEvents

    # @param [Boolean] success Whether records were successfully uploaded
    # @param [String] exception The exception that occured if an exception did occur
    # @param [Number] gpo_confirmation_count The number of GPO Confirmation records uploaded
    # GPO confirmation records were uploaded for letter sends
    def gpo_confirmation_upload(
      success:,
      exception:,
      gpo_confirmation_count:,
      **extra
    )
      track_event(
        :gpo_confirmation_upload,
        success: success,
        exception: exception,
        gpo_confirmation_count: gpo_confirmation_count,
        **extra,
      )
    end

    # @param [String] initiating_service_provider The service provider the user needs to connect to
    # The user chose not to connect their account from the SP follow-up page
    def idv_by_mail_sp_follow_up_cancelled(initiating_service_provider:, **extra)
      track_event(
        :idv_by_mail_sp_follow_up_cancelled,
        initiating_service_provider:,
        **extra,
      )
    end

    # @param [String] initiating_service_provider The service provider the user needs to connect to
    # The user chose to connect their account from the SP follow-up page
    def idv_by_mail_sp_follow_up_submitted(initiating_service_provider:, **extra)
      track_event(
        :idv_by_mail_sp_follow_up_submitted,
        initiating_service_provider:,
        **extra,
      )
    end

    # @param [String] initiating_service_provider The service provider the user needs to connect to
    # The user visited the SP follow-up page
    def idv_by_mail_sp_follow_up_visited(initiating_service_provider:, **extra)
      track_event(
        :idv_by_mail_sp_follow_up_visited,
        initiating_service_provider:,
        **extra,
      )
    end

    # @param [DateTime] enqueued_at When letter was enqueued
    # @param [Boolean] resend User requested a second (or more) letter
    # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
    # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
    #                  and now in hours
    # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
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
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # GPO letter was enqueued and the time at which it was enqueued
    def idv_gpo_address_letter_enqueued(
      enqueued_at:,
      resend:,
      first_letter_requested_at:,
      hours_since_first_letter:,
      phone_step_attempts:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: USPS address letter enqueued',
        enqueued_at:,
        resend:,
        first_letter_requested_at:,
        hours_since_first_letter:,
        phone_step_attempts:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Boolean] resend
    # @param [DateTime] first_letter_requested_at When the profile became gpo_pending
    # @param [Integer] hours_since_first_letter Difference between first_letter_requested_at
    #                  and now in hours
    # @param [Integer] phone_step_attempts Number of attempts at phone step before requesting letter
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
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # GPO letter was requested
    def idv_gpo_address_letter_requested(
      resend:,
      first_letter_requested_at:,
      hours_since_first_letter:,
      phone_step_attempts:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: USPS address letter requested',
        resend:,
        first_letter_requested_at:,
        hours_since_first_letter:,
        phone_step_attempts:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # The user visited the gpo confirm cancellation screen from RequestLetter
    def idv_gpo_confirm_start_over_before_letter_visited(**extra)
      track_event(:idv_gpo_confirm_start_over_before_letter_visited, **extra)
    end

    # The user visited the gpo confirm cancellation screen
    def idv_gpo_confirm_start_over_visited(**extra)
      track_event('IdV: gpo confirm start over visited', **extra)
    end

    # The user ran out of time to complete their address verification by mail.
    # @param [String] user_id UUID of the user who expired
    # @param [Boolean] user_has_active_profile Whether the user currently has an active profile
    # @param [Integer] letters_sent Total # of GPO letters sent for this profile
    # @param [Time] gpo_verification_pending_at Date/time when profile originally entered GPO flow
    def idv_gpo_expired(
      user_id:,
      user_has_active_profile:,
      letters_sent:,
      gpo_verification_pending_at:,
      **extra
    )
      track_event(
        :idv_gpo_expired,
        user_id: user_id,
        user_has_active_profile: user_has_active_profile,
        letters_sent: letters_sent,
        gpo_verification_pending_at: gpo_verification_pending_at,
        **extra,
      )
    end

    # A GPO reminder email was sent to the user
    # @param [String] user_id UUID of user who we sent a reminder to
    def idv_gpo_reminder_email_sent(user_id:, **extra)
      track_event('IdV: gpo reminder email sent', user_id: user_id, **extra)
    end

    # The user visited the "letter enqueued" page shown during the verify by mail flow
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
    # @identity.idp.previous_event_name IdV: come back later visited
    def idv_letter_enqueued_visit(
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: letter enqueued visited',
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile_idv_level,
        pending_profile_idv_level: pending_profile_idv_level,
        **extra,
      )
    end

    # Tracks when the user visits Mail only warning when vendor_status_sms is set to full_outage
    # @param [String] analytics_id Current IdV flow identifier
    def idv_mail_only_warning_visited(analytics_id:, **extra)
      track_event(
        'IdV: Mail only warning visited',
        analytics_id:,
        **extra,
      )
    end

    # GPO "request letter" page visited
    # @identity.idp.previous_event_name IdV: USPS address visited
    def idv_request_letter_visited(
      **extra
    )
      track_event(
        'IdV: request letter visited',
        **extra,
      )
    end

    # GPO "resend letter" page visited
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    # @identity.idp.previous_event_name IdV: request letter visited
    def idv_resend_letter_visited(
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        :idv_resend_letter_visited,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account verification submitted
    # @identity.idp.previous_event_name IdV: GPO verification submitted
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [DateTime] enqueued_at When was this letter enqueued
    # @param [Integer] which_letter Sorted by enqueue time, which letter had this code
    # @param [Integer] letter_count How many letters did the user enqueue for this profile
    # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
    # @param [String] initiating_service_provider The initiating service provider issuer
    # @param [Integer] submit_attempts Number of attempts to enter a correct code
    #                  (previously called "attempts")
    # @param [Boolean] pending_in_person_enrollment
    # @param [Boolean] fraud_check_failed
    # @see Reporting::IdentityVerificationReport#query This event is used by the identity verification
    #       report. Changes here should be reflected there.
    # GPO verification submitted
    def idv_verify_by_mail_enter_code_submitted(
      success:,
      enqueued_at:,
      which_letter:,
      letter_count:,
      profile_age_in_seconds:,
      initiating_service_provider:,
      submit_attempts:,
      pending_in_person_enrollment:,
      fraud_check_failed:,
      error_details: nil,
      **extra
    )
      track_event(
        'IdV: enter verify by mail code submitted',
        success:,
        error_details:,
        enqueued_at:,
        which_letter:,
        letter_count:,
        profile_age_in_seconds:,
        initiating_service_provider:,
        submit_attempts:,
        pending_in_person_enrollment:,
        fraud_check_failed:,
        **extra,
      )
    end

    # @identity.idp.previous_event_name Account verification visited
    # @identity.idp.previous_event_name IdV: GPO verification visited
    # Visited page used to enter address verification code received via US mail.
    # @param [String,nil] source The source for the visit (i.e., "gpo_reminder_email").
    # @param [Boolean] otp_rate_limited Whether the user is rate-limited
    # @param [Boolean] user_can_request_another_letter Whether user can request another letter
    def idv_verify_by_mail_enter_code_visited(
      source:,
      otp_rate_limited:,
      user_can_request_another_letter:,
      **extra
    )
      track_event(
        'IdV: enter verify by mail code visited',
        source:,
        otp_rate_limited:,
        user_can_request_another_letter:,
        **extra,
      )
    end
  end
end
