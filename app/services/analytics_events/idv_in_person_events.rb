# frozen_string_literal: true

module AnalyticsEvents
  module IdvInPersonEvents

    # User chooses to try In Person, e.g. from a doc_auth timeout error page
    # @param [Integer] remaining_submit_attempts The number of remaining attempts to submit
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] skip_hybrid_handoff Whether the user skipped the hybrid handoff A/B test
    # @param [Boolean] opted_in_to_in_person_proofing Whether the user opted into in-person proofing
    def idv_in_person_direct_start(
      remaining_submit_attempts:,
      flow_path:,
      skip_hybrid_handoff: nil,
      opted_in_to_in_person_proofing: nil,
      **extra
    )
      track_event(
        :idv_in_person_direct_start,
        remaining_submit_attempts:,
        flow_path:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # Tracks emails that are initiated during InPerson::EmailReminderJob
    # @param [String] email_type early or late
    # @param [String] enrollment_id
    def idv_in_person_email_reminder_job_email_initiated(
      email_type:,
      enrollment_id:,
      **extra
    )
      track_event(
        'InPerson::EmailReminderJob: Reminder email initiated',
        email_type: email_type,
        enrollment_id: enrollment_id,
        **extra,
      )
    end

    # Tracks exceptions that are raised when running InPerson::EmailReminderJob
    # @param [String] enrollment_id
    # @param [String] exception_class
    # @param [String] exception_message
    def idv_in_person_email_reminder_job_exception(
      enrollment_id:,
      exception_class: nil,
      exception_message: nil,
      **extra
    )
      track_event(
        'InPerson::EmailReminderJob: Exception raised when attempting to send reminder email',
        enrollment_id: enrollment_id,
        exception_class: exception_class,
        exception_message: exception_message,
        **extra,
      )
    end

    # @param [String] selected_location Selected in-person location
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user submitted the in person proofing location step
    def idv_in_person_location_submitted(
      selected_location:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing location submitted',
        selected_location: selected_location,
        flow_path: flow_path,
        opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user visited the in person proofing location step
    def idv_in_person_location_visited(flow_path:, opted_in_to_in_person_proofing:, **extra)
      track_event(
        'IdV: in person proofing location visited',
        flow_path: flow_path,
        opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
        **extra,
      )
    end

    # Tracks if request to get USPS in-person proofing locations fails
    # @param [Integer] api_status_code HTTP status code for API response
    # @param [String] exception_class
    # @param [String] exception_message
    # @param [Boolean] response_body_present
    # @param [Hash] response_body
    # @param [Integer] response_status_code
    def idv_in_person_locations_request_failure(
      api_status_code:,
      exception_class:,
      exception_message:,
      response_body_present:,
      response_body:,
      response_status_code:,
      **extra
    )
      track_event(
        'Request USPS IPP locations: request failed',
        api_status_code:,
        exception_class:,
        exception_message:,
        response_body_present:,
        response_body:,
        response_status_code:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Integer] result_total
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception_class
    # @param [String] exception_message
    # @param [Integer] response_status_code
    # User submitted a search on the location search page and response received
    def idv_in_person_locations_searched(
      success:,
      result_total: 0,
      errors: nil,
      exception_class: nil,
      exception_message: nil,
      response_status_code: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing location search submitted',
        success: success,
        result_total: result_total,
        errors: errors,
        exception_class: exception_class,
        exception_message: exception_message,
        response_status_code: response_status_code,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user submitted the in person proofing prepare step
    def idv_in_person_prepare_submitted(flow_path:, opted_in_to_in_person_proofing:, **extra)
      track_event(
        'IdV: in person proofing prepare submitted',
        flow_path: flow_path,
        opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user visited the in person proofing prepare step
    def idv_in_person_prepare_visited(flow_path:, opted_in_to_in_person_proofing:, **extra)
      track_event(
        'IdV: in person proofing prepare visited',
        flow_path: flow_path,
        opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step
    # @param [String] analytics_id
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    #   address page visited
    def idv_in_person_proofing_address_visited(
      flow_path:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing address visited',
        flow_path:,
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # @param [Boolean] success
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ['drivers_license', 'passport'] chosen_id_type Chosen id type of the user
    # @param [Boolean] opted_in_to_in_person_proofing Whether user opted into in person proofing
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash] error_details
    def idv_in_person_proofing_choose_id_type_submitted(
      success:,
      flow_path:,
      step:,
      analytics_id:,
      chosen_id_type:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      error_details: nil,
      **extra
    )
      track_event(
        :idv_in_person_proofing_choose_id_type_submitted,
        success:,
        flow_path:,
        step:,
        analytics_id:,
        chosen_id_type:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        error_details:,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id
    # @param [Boolean] opted_in_to_in_person_proofing Whether user opted into in person proofing
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    def idv_in_person_proofing_choose_id_type_visited(
      flow_path:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        :idv_in_person_proofing_choose_id_type_visited,
        flow_path:,
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # A job to check USPS notifications about in-person enrollment status updates has completed
    # @param [Integer] fetched_items items fetched
    # @param [Integer] processed_items items fetched and processed
    # @param [Integer] deleted_items items fetched, processed, and then deleted from the queue
    # @param [Integer] valid_items items that could be successfully used to update a record
    # @param [Integer] invalid_items items that couldn't be used to update a record
    # @param [Integer] incomplete_items fetched items not processed nor deleted from the queue
    # @param [Integer] deletion_failed_items processed items that we failed to delete
    def idv_in_person_proofing_enrollments_ready_for_status_check_job_completed(
      fetched_items:,
      processed_items:,
      deleted_items:,
      valid_items:,
      invalid_items:,
      incomplete_items:,
      deletion_failed_items:,
      **extra
    )
      track_event(
        'InPersonEnrollmentsReadyForStatusCheckJob: Job completed',
        fetched_items:,
        processed_items:,
        deleted_items:,
        valid_items:,
        invalid_items:,
        incomplete_items:,
        deletion_failed_items:,
        **extra,
      )
    end

    # A job to check USPS notifications about in-person enrollment status updates
    # has encountered an error
    # @param [String] exception_class
    # @param [String] exception_message
    def idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error(
      exception_class:,
      exception_message:,
      **extra
    )
      track_event(
        'InPersonEnrollmentsReadyForStatusCheckJob: Ingestion error',
        exception_class:,
        exception_message:,
        **extra,
      )
    end

    # A job to check USPS notifications about in-person enrollment status updates has started
    def idv_in_person_proofing_enrollments_ready_for_status_check_job_started(**extra)
      track_event(
        'InPersonEnrollmentsReadyForStatusCheckJob: Job started',
        **extra,
      )
    end

    # @param [String] nontransliterable_characters
    # Nontransliterable characters submitted by user
    def idv_in_person_proofing_nontransliterable_characters_submitted(
      nontransliterable_characters:,
      **extra
    )
      track_event(
        'IdV: in person proofing characters submitted could not be transliterated',
        nontransliterable_characters: nontransliterable_characters,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # The user visited the ID-IPP passport data collection form
    def idv_in_person_proofing_passport_submitted(
      success:,
      flow_path:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      error_details: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        :idv_in_person_proofing_passport_submitted,
        success:,
        flow_path:,
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        error_details:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # The user visited the ID-IPP passport data collection form
    def idv_in_person_proofing_passport_visited(
      flow_path: nil,
      step: nil,
      analytics_id: nil,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        :idv_in_person_proofing_passport_visited,
        flow_path:,
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [String] current_address_zip_code ZIP code of given address
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_in_person_proofing_residential_address_submitted(
      success:,
      flow_path:,
      step:,
      analytics_id:,
      current_address_zip_code:,
      opted_in_to_in_person_proofing: nil,
      error_details: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing residential address submitted',
        success:,
        flow_path:,
        step:,
        analytics_id:,
        current_address_zip_code:,
        opted_in_to_in_person_proofing:,
        error_details:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step
    # @param [String] analytics_id
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [String] birth_year Birth year from document
    # @param [String] document_zip_code ZIP code from document
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # User submitted state id
    def idv_in_person_proofing_state_id_submitted(
      success:,
      flow_path:,
      step:,
      analytics_id:,
      birth_year:,
      document_zip_code:,
      skip_hybrid_handoff: nil,
      error_details: nil,
      opted_in_to_in_person_proofing: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing state_id submitted',
        flow_path:,
        step:,
        analytics_id:,
        success:,
        error_details:,
        birth_year:,
        document_zip_code:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step
    # @param [String] analytics_id
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # State id page visited
    def idv_in_person_proofing_state_id_visited(
      flow_path: nil,
      step: nil,
      analytics_id: nil,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: in person proofing state_id visited',
        flow_path:,
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # The user clicked the "Update" link for address on the verify info page
    def idv_in_person_proofing_verify_info_update_address_button_clicked(**extra)
      track_event(
        :idv_in_person_proofing_verify_info_update_address_button_clicked,
        **extra,
      )
    end

    # The user clicked the "Update" link for SSN on the verify info page
    def idv_in_person_proofing_verify_info_update_ssn_button_clicked(**extra)
      track_event(
        :idv_in_person_proofing_verify_info_update_ssn_button_clicked,
        **extra,
      )
    end

    # The user clicked the "Update" link for state ID on the verify info page
    def idv_in_person_proofing_verify_info_update_state_id_button_clicked(**extra)
      track_event(
        :idv_in_person_proofing_verify_info_update_state_id_button_clicked,
        **extra,
      )
    end

    # The user clicked the sp link on the "ready to verify" page
    def idv_in_person_ready_to_verify_sp_link_clicked(**extra)
      track_event(
        'IdV: user clicked sp link on ready to verify page',
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
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # The user visited the "ready to verify" page for the in person proofing flow
    def idv_in_person_ready_to_verify_visit(
      opted_in_to_in_person_proofing: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        'IdV: in person ready to verify visited',
        opted_in_to_in_person_proofing:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # The user clicked the what to bring link on the "ready to verify" page
    def idv_in_person_ready_to_verify_what_to_bring_link_clicked(**extra)
      track_event(
        'IdV: user clicked what to bring link on ready to verify page',
        **extra,
      )
    end

    # Track sms notification attempt
    # @param [boolean] success sms notification successful or not
    # @param [String] enrollment_code enrollment_code
    # @param [String] enrollment_id enrollment_id
    # @param [Hash] telephony_response Response from Telephony gem
    # @param [Hash] extra extra information
    def idv_in_person_send_proofing_notification_attempted(
      success:,
      enrollment_code:,
      enrollment_id:,
      telephony_response:,
      **extra
    )
      track_event(
        'SendProofingNotificationJob: in person notification SMS send attempted',
        success: success,
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        telephony_response: telephony_response,
        **extra,
      )
    end

    # Track sms notification job completion
    # @param [String] enrollment_code enrollment_code
    # @param [String] enrollment_id enrollment_id
    # @param [Hash] extra extra information
    def idv_in_person_send_proofing_notification_job_completed(
      enrollment_code:,
      enrollment_id:,
      **extra
    )
      track_event(
        'SendProofingNotificationJob: job completed',
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        **extra,
      )
    end

    # Tracks exceptions that are raised when running InPerson::SendProofingNotificationJob
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [String] exception_class
    # @param [String] exception_message
    # @param [Hash] extra extra information
    def idv_in_person_send_proofing_notification_job_exception(
      enrollment_code:,
      enrollment_id:,
      exception_class: nil,
      exception_message: nil,
      **extra
    )
      track_event(
        'SendProofingNotificationJob: exception raised',
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        exception_class: exception_class,
        exception_message: exception_message,
        **extra,
      )
    end

    # Track sms notification job skipped
    # @param [String] enrollment_code enrollment_code
    # @param [String] enrollment_id enrollment_id
    # @param [Hash] extra extra information
    def idv_in_person_send_proofing_notification_job_skipped(
      enrollment_code:,
      enrollment_id:,
      **extra
    )
      track_event(
        'SendProofingNotificationJob: job skipped',
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        **extra,
      )
    end

    # Track sms notification job started
    # @param [String] enrollment_code enrollment_code
    # @param [String] enrollment_id enrollment_id
    # @param [Hash] extra extra information
    def idv_in_person_send_proofing_notification_job_started(
      enrollment_code:,
      enrollment_id:,
      **extra
    )
      track_event(
        'SendProofingNotificationJob: job started',
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # The user submitted the in person proofing switch_back step
    def idv_in_person_switch_back_submitted(flow_path:, **extra)
      track_event('IdV: in person proofing switch_back submitted', flow_path: flow_path, **extra)
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # The user visited the in person proofing switch_back step
    def idv_in_person_switch_back_visited(flow_path:, **extra)
      track_event('IdV: in person proofing switch_back visited', flow_path: flow_path, **extra)
    end

    # An email from USPS with an enrollment code has been received, indicating
    # the enrollment is approved or failed. A check is required to get the status
    # it is not included in the email.
    # @param [boolean] multi_part If the email is marked as multi_part
    # @param [string] part_found Records if the enrollment code was found in text_part or html_part
    def idv_in_person_usps_proofing_enrollment_code_email_received(
      multi_part: nil,
      part_found: nil,
      **extra
    )
      track_event(
        'IdV: in person usps proofing enrollment code email received',
        multi_part: multi_part,
        part_found: part_found,
        **extra,
      )
    end

    # GetUspsProofingResultsJob has completed. Includes counts of various outcomes encountered
    # @param [Float] duration_seconds number of minutes the job was running
    # @param [Integer] enrollments_checked number of enrollments eligible for status check
    # @param [Integer] enrollments_errored number of enrollments for which we encountered an error
    # @param [Integer] enrollments_expired number of enrollments which expired
    # @param [Integer] enrollments_failed number of enrollments which failed identity proofing
    # @param [Integer] enrollments_in_progress number of enrollments which did not have any change
    # @param [Integer] enrollments_passed number of enrollments which passed identity proofing
    # @param [Integer] enrollments_in_fraud_review number of enrollments in fraud review
    # @param [Integer] enrollments_skipped number of enrollments skipped
    # @param [Integer] enrollments_network_error
    # @param [Integer] enrollments_cancelled
    # @param [Float] percent_enrollments_errored
    # @param [Float] percent_enrollments_network_error
    # @param [String] job_name
    def idv_in_person_usps_proofing_results_job_completed(
      duration_seconds:,
      enrollments_checked:,
      enrollments_errored:,
      enrollments_expired:,
      enrollments_failed:,
      enrollments_in_progress:,
      enrollments_passed:,
      enrollments_in_fraud_review:,
      enrollments_skipped:,
      enrollments_network_error:,
      enrollments_cancelled:,
      percent_enrollments_errored:,
      percent_enrollments_network_error:,
      job_name:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Job completed',
        duration_seconds:,
        enrollments_checked:,
        enrollments_errored:,
        enrollments_expired:,
        enrollments_failed:,
        enrollments_in_progress:,
        enrollments_passed:,
        enrollments_in_fraud_review:,
        enrollments_skipped:,
        enrollments_network_error:,
        enrollments_cancelled:,
        percent_enrollments_errored:,
        percent_enrollments_network_error:,
        job_name:,
        **extra,
      )
    end

    # Tracks exceptions that are raised when initiating deadline email in GetUspsProofingResultsJob
    # @param [String] enrollment_id
    # @param [String] exception_class
    # @param [String] exception_message
    def idv_in_person_usps_proofing_results_job_deadline_passed_email_exception(
      enrollment_id:,
      exception_class: nil,
      exception_message: nil,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Exception raised when attempting to send deadline passed email',
        enrollment_id: enrollment_id,
        exception_class: exception_class,
        exception_message: exception_message,
        **extra,
      )
    end

    # Tracks deadline email initiated during GetUspsProofingResultsJob
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [Time] timestamp
    # @param [String] service_provider
    # @param [Integer] wait_until
    # @param [String] job_name
    def idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated(
      enrollment_code:,
      enrollment_id:,
      timestamp:,
      service_provider:,
      wait_until:,
      job_name:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: deadline passed email initiated',
        enrollment_code:,
        enrollment_id:,
        timestamp:,
        service_provider:,
        wait_until:,
        job_name:,
        **extra,
      )
    end

    # Tracks emails that are initiated during GetUspsProofingResultsJob
    # @param [String] email_type success, failed or failed fraud
    # @param [String] enrollment_code
    # @param [Time] timestamp
    # @param [String] service_provider
    # @param [Integer] wait_until
    # @param [String] job_name
    def idv_in_person_usps_proofing_results_job_email_initiated(
      email_type:,
      enrollment_code:,
      timestamp:,
      service_provider:,
      wait_until:,
      job_name:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Success or failure email initiated',
        email_type:,
        enrollment_code:,
        timestamp:,
        service_provider:,
        wait_until:,
        job_name:,
        **extra,
      )
    end

    # Tracks incomplete enrollments checked via the USPS API
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [Float] minutes_since_established
    # @param [String] response_message
    def idv_in_person_usps_proofing_results_job_enrollment_incomplete(
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      response_message:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Enrollment incomplete',
        enrollment_code: enrollment_code,
        enrollment_id: enrollment_id,
        minutes_since_established: minutes_since_established,
        response_message: response_message,
        **extra,
      )
    end

    # Tracks skipped enrollments during the execution of the GetUspsProofingResultsJob
    # @param [String] enrollment_code The in-person enrollment code.
    # @param [String] enrollment_id The in-person enrollment ID.
    # @param [String] reason The reason for skipping the enrollment.
    # @param [String] job_name The class name of the job.
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [String] issuer
    # @param [Boolean] response_present
    # @param [Boolean] fraud_suspected
    # @param [String] primary_id_type
    # @param [String] secondary_id_type
    # @param [String] failure_reason
    # @param [String] transaction_end_date_time
    # @param [String] transaction_start_date_time
    # @param [String] status
    # @param [String] assurance_level
    # @param [String] proofing_post_office
    # @param [String] proofing_city
    # @param [String] proofing_state
    # @param [String] scan_count
    # @param [String] response_message
    def idv_in_person_usps_proofing_results_job_enrollment_skipped(
      enrollment_code:,
      enrollment_id:,
      reason:,
      job_name:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      response_present:,
      fraud_suspected: nil,
      primary_id_type: nil,
      secondary_id_type: nil,
      failure_reason: nil,
      transaction_end_date_time: nil,
      transaction_start_date_time: nil,
      status: nil,
      assurance_level: nil,
      proofing_post_office: nil,
      proofing_city: nil,
      proofing_state: nil,
      scan_count: nil,
      response_message: nil,
      **extra
    )
      track_event(
        :idv_in_person_usps_proofing_results_job_enrollment_skipped,
        enrollment_code:,
        enrollment_id:,
        reason:,
        job_name:,
        minutes_since_established:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        issuer:,
        response_present:,
        fraud_suspected:,
        primary_id_type:,
        secondary_id_type:,
        failure_reason:,
        transaction_end_date_time:,
        transaction_start_date_time:,
        status:,
        assurance_level:,
        proofing_post_office:,
        proofing_city:,
        proofing_state:,
        scan_count:,
        response_message:,
        **extra,
      )
    end

    # Tracks individual enrollments that are updated during GetUspsProofingResultsJob
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [Boolean] fraud_suspected
    # @param [String] primary_id_type
    # @param [String] secondary_id_type
    # @param [String] failure_reason
    # @param [String] transaction_end_date_time
    # @param [String] transaction_start_date_time
    # @param [String] status
    # @param [String] assurance_level
    # @param [String] proofing_post_office
    # @param [String] proofing_city
    # @param [String] proofing_state
    # @param [String] scan_count
    # @param [String] response_message
    # @param [Boolean] passed did this enrollment pass or fail?
    # @param [String] reason why did this enrollment pass or fail?
    # @param [String] tmx_status the tmx_status of the enrollment profile
    # @param [Integer] profile_age_in_seconds How many seconds have passed since profile created
    # @param [Boolean] response_present
    # @param [String] job_name
    # @param [Boolean] enhanced_ipp
    # @param [String] issuer
    def idv_in_person_usps_proofing_results_job_enrollment_updated(
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      passed:,
      reason:,
      tmx_status:,
      profile_age_in_seconds:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      response_present:,
      job_name:,
      enhanced_ipp:,
      issuer:,
      fraud_suspected: nil,
      primary_id_type: nil,
      secondary_id_type: nil,
      failure_reason: nil,
      transaction_end_date_time: nil,
      transaction_start_date_time: nil,
      status: nil,
      assurance_level: nil,
      proofing_post_office: nil,
      proofing_city: nil,
      proofing_state: nil,
      scan_count: nil,
      response_message: nil,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Enrollment status updated',
        enrollment_code:,
        enrollment_id:,
        minutes_since_established:,
        passed:,
        reason:,
        tmx_status:,
        profile_age_in_seconds:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        fraud_suspected:,
        primary_id_type:,
        secondary_id_type:,
        failure_reason:,
        transaction_end_date_time:,
        transaction_start_date_time:,
        status:,
        assurance_level:,
        proofing_post_office:,
        proofing_city:,
        proofing_state:,
        scan_count:,
        response_present:,
        response_message:,
        job_name:,
        enhanced_ipp:,
        issuer:,
        **extra,
      )
    end

    # Tracks exceptions that are raised when running GetUspsProofingResultsJob
    # @param [String] reason why was the exception raised?
    # @param [String] enrollment_id
    # @param [String] exception_class
    # @param [String] exception_message
    # @param [String] enrollment_code
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [Boolean] fraud_suspected
    # @param [String] primary_id_type
    # @param [String] secondary_id_type
    # @param [String] failure_reason
    # @param [String] transaction_end_date_time
    # @param [String] transaction_start_date_time
    # @param [String] status
    # @param [String] assurance_level
    # @param [String] proofing_post_office
    # @param [String] proofing_city
    # @param [String] proofing_state
    # @param [String] scan_count
    # @param [Boolean] response_present
    # @param [String] response_message
    # @param [Integer] response_status_code
    # @param [String] job_name
    # @param [String] issuer
    def idv_in_person_usps_proofing_results_job_exception(
      reason:,
      enrollment_id:,
      minutes_since_established:,
      exception_class: nil,
      exception_message: nil,
      enrollment_code: nil,
      minutes_since_last_status_check: nil,
      minutes_since_last_status_check_completed: nil,
      minutes_since_last_status_update: nil,
      minutes_to_completion: nil,
      fraud_suspected: nil,
      primary_id_type: nil,
      secondary_id_type: nil,
      failure_reason: nil,
      transaction_end_date_time: nil,
      transaction_start_date_time: nil,
      status: nil,
      assurance_level: nil,
      proofing_post_office: nil,
      proofing_city: nil,
      proofing_state: nil,
      scan_count: nil,
      response_present: nil,
      response_message: nil,
      response_status_code: nil,
      job_name: nil,
      issuer: nil,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Exception raised',
        reason:,
        enrollment_id:,
        exception_class:,
        exception_message:,
        enrollment_code:,
        minutes_since_established:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        fraud_suspected:,
        primary_id_type:,
        secondary_id_type:,
        failure_reason:,
        transaction_end_date_time:,
        transaction_start_date_time:,
        status:,
        assurance_level:,
        proofing_post_office:,
        proofing_city:,
        proofing_state:,
        scan_count:,
        response_present:,
        response_message:,
        response_status_code:,
        job_name:,
        issuer:,
        **extra,
      )
    end

    # Tracks enrollments that were cancelled after spending over 90 days in password reset.
    # @param [String] enrollment_code The in-person enrollment code.
    # @param [String] enrollment_id The in-person enrollment ID.
    # @param [String] reason The reason for cancelling the enrollment.
    # @param [String] job_name The class name of the job.
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [String] issuer
    def idv_in_person_usps_proofing_results_job_password_reset_enrollment_cancelled(
      enrollment_code:,
      enrollment_id:,
      reason:,
      job_name:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      **extra
    )
      track_event(
        :idv_in_person_usps_proofing_results_job_password_reset_enrollment_cancelled,
        enrollment_code:,
        enrollment_id:,
        reason:,
        job_name:,
        minutes_since_established:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        issuer:,
        **extra,
      )
    end

    # Tracks please call emails that are initiated during GetUspsProofingResultsJob
    # @param [String] enrollment_code
    # @param [String] job_name
    # @param [String] service_provider
    # @param [Time] timestamp
    # @param [Integer] wait_until
    def idv_in_person_usps_proofing_results_job_please_call_email_initiated(
      enrollment_code:,
      job_name:,
      service_provider:,
      timestamp:,
      wait_until:,
      **extra
    )
      track_event(
        :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
        enrollment_code:,
        job_name:,
        service_provider:,
        timestamp:,
        wait_until:,
        **extra,
      )
    end

    # GetUspsProofingResultsJob is beginning. Includes some metadata about what the job will do
    # @param [Integer] enrollments_count number of enrollments eligible for status check
    # @param [Integer] reprocess_delay_minutes minimum delay since last status check
    # @param [String] job_name Name of class which triggered proofing job
    def idv_in_person_usps_proofing_results_job_started(
      enrollments_count:,
      reprocess_delay_minutes:,
      job_name:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Job started',
        enrollments_count:,
        reprocess_delay_minutes:,
        job_name:,
        **extra,
      )
    end

    # Tracks unexpected responses from the USPS API
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [String] issuer
    # @param [String] job_name
    # @param [String] response_message
    # @param [String] reason why was this error unexpected?
    def idv_in_person_usps_proofing_results_job_unexpected_response(
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      job_name:,
      response_message:,
      reason:,
      **extra
    )
      track_event(
        'GetUspsProofingResultsJob: Unexpected response received',
        enrollment_code:,
        enrollment_id:,
        minutes_since_established:,
        response_message:,
        reason:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        issuer:,
        job_name:,
        **extra,
      )
    end

    # A user has been moved to fraud review after completing proofing at the USPS
    # @param [String] enrollment_code
    # @param [String] enrollment_id
    # @param [Float] minutes_since_established
    # @param [Float] minutes_since_last_status_check
    # @param [Float] minutes_since_last_status_check_completed
    # @param [Float] minutes_since_last_status_update
    # @param [Float] minutes_to_completion
    # @param [String] issuer
    def idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review(
      enrollment_code:,
      enrollment_id:,
      minutes_since_established:,
      minutes_since_last_status_check:,
      minutes_since_last_status_check_completed:,
      minutes_since_last_status_update:,
      minutes_to_completion:,
      issuer:,
      **extra
    )
      track_event(
        :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
        enrollment_code:,
        enrollment_id:,
        minutes_since_established:,
        minutes_since_last_status_check:,
        minutes_since_last_status_check_completed:,
        minutes_since_last_status_update:,
        minutes_to_completion:,
        issuer:,
        **extra,
      )
    end

    # Tracks if USPS in-person proofing enrollment request fails
    # @param [String] context
    # @param [String] reason
    # @param [Integer] enrollment_id
    # @param [String] exception_class
    # @param [String] original_exception_class
    # @param [String] exception_message
    def idv_in_person_usps_request_enroll_exception(
      context:,
      reason:,
      enrollment_id:,
      exception_class:,
      original_exception_class:,
      exception_message:,
      **extra
    )
      track_event(
        'USPS IPPaaS enrollment failed',
        context:,
        enrollment_id:,
        exception_class:,
        original_exception_class:,
        exception_message:,
        reason:,
        **extra,
      )
    end

    # IPP AAMVA proofing result is missing from Redis (expired or not found)
    # @param [Hash] extra Additional event data
    def idv_ipp_aamva_proofing_result_missing(**extra)
      track_event(:idv_ipp_aamva_proofing_result_missing, **extra)
    end

    # @param [String] step Current step in the IPP flow
    # AAMVA rate limit hit for IPP user
    def idv_ipp_aamva_rate_limited(
      step:,
      **extra
    )
      track_event(
        :idv_ipp_aamva_rate_limited,
        step:,
        **extra,
      )
    end

    # @param [Boolean] success Whether the AAMVA verification succeeded
    # @param [String] vendor_name Name of the AAMVA vendor
    # @param [String] step Current step in the IPP flow
    # AAMVA verification completed for IPP user
    def idv_ipp_aamva_verification_completed(
      success:,
      vendor_name:,
      step:,
      **extra
    )
      track_event(
        :idv_ipp_aamva_verification_completed,
        success:,
        vendor_name:,
        step:,
        **extra,
      )
    end

    # User visited polling wait page for IPP AAMVA verification
    def idv_ipp_aamva_verification_polling_wait(**extra)
      track_event(:idv_ipp_aamva_verification_polling_wait, **extra)
    end

    # @param [String] enrollment_id
    # A fraud user has been deactivated due to not visting the post office before the deadline
    def idv_ipp_deactivated_for_never_visiting_post_office(
      enrollment_id:,
      **extra
    )
      track_event(
        :idv_ipp_deactivated_for_never_visiting_post_office,
        enrollment_id: enrollment_id,
        **extra,
      )
    end

    # Track when USPS auth token refresh job completed
    def idv_usps_auth_token_refresh_job_completed(**extra)
      track_event(
        'UspsAuthTokenRefreshJob: Completed',
        **extra,
      )
    end

    # Track when USPS auth token refresh job encounters a network error
    # @param [String] exception_class
    # @param [String] exception_message
    def idv_usps_auth_token_refresh_job_network_error(exception_class:, exception_message:, **extra)
      track_event(
        'UspsAuthTokenRefreshJob: Network error',
        exception_class: exception_class,
        exception_message: exception_message,
        **extra,
      )
    end

    # Track when USPS auth token refresh job started
    def idv_usps_auth_token_refresh_job_started(**extra)
      track_event(
        'UspsAuthTokenRefreshJob: Started',
        **extra,
      )
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Integer] submit_attempts Times that user has tried submitting document capture
    # The user clicked the troubleshooting option to start in-person proofing
    def idv_verify_in_person_troubleshooting_option_clicked(
      flow_path:,
      opted_in_to_in_person_proofing:,
      submit_attempts:,
      **extra
    )
      track_event(
        'IdV: verify in person troubleshooting option clicked',
        flow_path: flow_path,
        opted_in_to_in_person_proofing: opted_in_to_in_person_proofing,
        submit_attempts: submit_attempts,
        **extra,
      )
    end

    # Tracks when USPS in-person proofing enrollment is created
    # @param [String] enrollment_code
    # @param [Integer] enrollment_id
    # @param [Boolean] second_address_line_present
    # @param [String] service_provider
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [String] tmx_status the tmx_status of the enrollment profile profile
    # @param [Boolean] enhanced_ipp Whether enrollment is for enhanced in-person proofing
    def usps_ippaas_enrollment_created(
      enrollment_code:,
      enrollment_id:,
      second_address_line_present:,
      service_provider:,
      opted_in_to_in_person_proofing:,
      tmx_status:,
      enhanced_ipp:,
      **extra
    )
      track_event(
        'USPS IPPaaS enrollment created',
        enrollment_code:,
        enrollment_id:,
        second_address_line_present:,
        service_provider:,
        opted_in_to_in_person_proofing:,
        tmx_status:,
        enhanced_ipp:,
        **extra,
      )
    end
  end
end
