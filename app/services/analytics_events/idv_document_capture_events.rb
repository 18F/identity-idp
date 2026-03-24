# frozen_string_literal: true

module AnalyticsEvents
  module IdvDocumentCaptureEvents

    # @param [String] message the warning
    # @param [Array<String>] unknown_alerts Names of alerts not recognized by our code
    # @param [Hash] response_info Response payload
    # Logged when there is a non-user-facing error in the doc auth process, such as an unrecognized
    # field from a vendor
    def doc_auth_warning(message: nil, unknown_alerts: nil, response_info: nil, **extra)
      track_event(
        'Doc Auth Warning',
        message:,
        unknown_alerts:,
        response_info:,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] isCameraSupported
    # @param [Boolean] success
    # @param [Boolean] use_alternate_sdk
    # @param [Boolean] liveness_checking_required
    # The Acuant SDK was loaded
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_acuant_sdk_loaded(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      isCameraSupported:,
      success:,
      use_alternate_sdk:,
      liveness_checking_required:,
      **extra
    )
      track_event(
        'Frontend: IdV: Acuant SDK loaded',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        isCameraSupported: isCameraSupported,
        success: success,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        **extra,
      )
    end

    # @param [String] acuantCaptureMode
    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param [Boolean] assessment
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [String] documentType
    # @param [Integer] dpi  dots per inch of image
    # @param [Integer] failedImageResubmission
    # @param [String] fingerprint fingerprint of the image added
    # @param [String] flow_path whether the user is in the hybrid or standard flow
    # @param [Integer] glare
    # @param [Integer] glareScoreThreshold
    # @param [Integer] height height of image added in pixels
    # @param [Boolean] isAssessedAsBlurry
    # @param [Boolean] isAssessedAsGlare
    # @param [Boolean] isAssessedAsUnsupported
    # @param [String] mimeType MIME type of image added
    # @param [Integer] moire
    # @param [Integer] sharpness
    # @param [Integer] sharpnessScoreThreshold
    # @param [Integer] size size of image added in bytes
    # @param [String] source
    # @param [Boolean] use_alternate_sdk
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [Integer] width width of image added in pixels
    # Back image was added in document capture
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_back_image_added(
      acuantCaptureMode:,
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      assessment:,
      captureAttempts:,
      documentType:,
      dpi:,
      failedImageResubmission:,
      fingerprint:,
      flow_path:,
      glare:,
      glareScoreThreshold:,
      height:,
      isAssessedAsBlurry:,
      isAssessedAsGlare:,
      isAssessedAsUnsupported:,
      mimeType:,
      moire:,
      sharpness:,
      sharpnessScoreThreshold:,
      size:,
      source:,
      use_alternate_sdk:,
      liveness_checking_required:,
      width:,
      **extra
    )
      track_event(
        'Frontend: IdV: back image added',
        acuantCaptureMode: acuantCaptureMode,
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        assessment: assessment,
        captureAttempts: captureAttempts,
        documentType: documentType,
        dpi: dpi,
        failedImageResubmission: failedImageResubmission,
        fingerprint: fingerprint,
        flow_path: flow_path,
        glare: glare,
        glareScoreThreshold: glareScoreThreshold,
        height: height,
        isAssessedAsBlurry: isAssessedAsBlurry,
        isAssessedAsGlare: isAssessedAsGlare,
        isAssessedAsUnsupported: isAssessedAsUnsupported,
        mimeType: mimeType,
        moire: moire,
        sharpness: sharpness,
        sharpnessScoreThreshold: sharpnessScoreThreshold,
        size: size,
        source: source,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        width: width,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] isDrop
    # @param [Boolean] click_source
    # @param [Boolean] use_alternate_sdk
    # @param [Number] captureAttempts count of image capturing attempts
    # @param [String] liveness_checking_required Whether or not the selfie is required
    def idv_back_image_clicked(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      isDrop:,
      click_source:,
      use_alternate_sdk:,
      captureAttempts:,
      liveness_checking_required:,
      **extra
    )
      track_event(
        'Frontend: IdV: back image clicked',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        isDrop: isDrop,
        click_source: click_source,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        captureAttempts: captureAttempts,
        **extra,
      )
    end

    # @param [String] liveness_checking_required Whether or not the selfie is required
    def idv_barcode_warning_continue_clicked(liveness_checking_required:, **extra)
      track_event(
        'Frontend: IdV: barcode warning continue clicked',
        liveness_checking_required: liveness_checking_required,
        **extra,
      )
    end

    # @param [String] liveness_checking_required Whether or not the selfie is required
    def idv_barcode_warning_retake_photos_clicked(liveness_checking_required:, **extra)
      track_event(
        'Frontend: IdV: barcode warning retake photos clicked',
        liveness_checking_required: liveness_checking_required,
        **extra,
      )
    end

    # @param [Hash] error
    def idv_camera_info_error(error:, **extra)
      track_event(:idv_camera_info_error, error:, **extra)
    end

    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Array] camera_info Information on the users cameras max resolution
    #   as captured by the browser
    def idv_camera_info_logged(flow_path:, camera_info:, **extra)
      track_event(:idv_camera_info_logged, flow_path:, camera_info:, **extra)
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] use_alternate_sdk
    # @param [Boolean] liveness_checking_required
    # @param [Integer] submit_attempts Times that user has tried submitting document capture
    def idv_capture_troubleshooting_dismissed(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      use_alternate_sdk:,
      liveness_checking_required:,
      submit_attempts:,
      **extra
    )
      track_event(
        'Frontend: IdV: Capture troubleshooting dismissed',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        submit_attempts: submit_attempts,
        **extra,
      )
    end

    # @param [String] step_name
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # The user was sent to a warning page during the IDV flow
    def idv_doc_auth_address_warning_visited(step_name:, remaining_submit_attempts:, **extra)
      track_event(
        :idv_doc_auth_address_warning_visited,
        step_name: step_name,
        remaining_submit_attempts: remaining_submit_attempts,
        **extra,
      )
    end

    # User has consented to share information with document upload and may
    # view the "hybrid handoff" step next unless "skip_hybrid_handoff" param is true
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_agreement_submitted(
      success:,
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      error_details: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth agreement submitted',
        success:,
        error_details:,
        step:,
        analytics_id:,
        acuant_sdk_upgrade_ab_test_bucket:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # User visits IdV agreement step
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_agreement_visited(
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth agreement visited',
        step:,
        analytics_id:,
        acuant_sdk_upgrade_ab_test_bucket:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] liveness_checking_required Whether facial match check is required
    def idv_doc_auth_capture_complete_visited(
      step:,
      analytics_id:,
      flow_path:,
      liveness_checking_required:,
      **extra
    )
      track_event(
        'IdV: doc auth capture_complete visited',
        step:,
        analytics_id:,
        flow_path:,
        liveness_checking_required:,
        **extra,
      )
    end

    # @param [Boolean] success
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param ['drivers_license', 'passport'] chosen_id_type Chosen id type of the user
    # @param [Hash] error_details
    def idv_doc_auth_choose_id_type_submitted(
      success:,
      step:,
      analytics_id:,
      flow_path:,
      chosen_id_type:,
      error_details: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_choose_id_type_submitted,
        success:,
        step:,
        analytics_id:,
        flow_path:,
        chosen_id_type:,
        error_details:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    def idv_doc_auth_choose_id_type_visited(
      step:,
      analytics_id:,
      flow_path:,
      **extra
    )
      track_event(
        :idv_doc_auth_choose_id_type_visited,
        step:,
        analytics_id:,
        flow_path:,
        **extra,
      )
    end

    # User returns from Socure document capture, but is waiting on a result to be fetched
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] liveness_checking_required Whether facial match check is required
    # @param [Boolean] selfie_check_required Whether facial match check is required
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    def idv_doc_auth_document_capture_polling_wait_visited(
      flow_path:,
      step:,
      analytics_id:,
      liveness_checking_required:,
      selfie_check_required:,
      redo_document_capture: nil,
      skip_hybrid_handoff: nil,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_document_capture_polling_wait_visited,
        flow_path:,
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        liveness_checking_required:,
        selfie_check_required:,
        opted_in_to_in_person_proofing:,
        acuant_sdk_upgrade_ab_test_bucket:,
        **extra,
      )
    end

    # User submits IdV document capture step
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] liveness_checking_required Whether facial match check is required
    # @param [Boolean] selfie_check_required Whether facial match check is required
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
    #   warning
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] stored_result_present Whether a stored result was present
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_document_capture_submitted(
      success:,
      step:,
      analytics_id:,
      liveness_checking_required:,
      selfie_check_required:,
      flow_path:,
      errors: nil,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      redo_document_capture: nil,
      skip_hybrid_handoff: nil,
      stored_result_present: nil,
      **extra
    )
      track_event(
        'IdV: doc auth document_capture submitted',
        success:,
        errors:,
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        liveness_checking_required:,
        selfie_check_required:,
        acuant_sdk_upgrade_ab_test_bucket:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        stored_result_present:,
        **extra,
      )
    end

    # User visits IdV document capture step
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
    #   warning
    # @param [Boolean] liveness_checking_required Whether facial match check is required
    # @param [Boolean] selfie_check_required Whether facial match check is required
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_document_capture_visited(
      step:,
      analytics_id:,
      liveness_checking_required:,
      selfie_check_required:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      redo_document_capture: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth document_capture visited',
        flow_path:,
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        liveness_checking_required:,
        selfie_check_required:,
        opted_in_to_in_person_proofing:,
        acuant_sdk_upgrade_ab_test_bucket:,
        **extra,
      )
    end

    # @param [String] step_name which step the user was on
    # @param [Integer] remaining_submit_attempts how many attempts the user has left before
    #                  we rate limit them (previously called "remaining_attempts")
    # The user visited an error page due to an encountering an exception talking to a proofing vendor
    def idv_doc_auth_exception_visited(step_name:, remaining_submit_attempts:, **extra)
      track_event(
        'IdV: doc auth exception visited',
        step_name: step_name,
        remaining_submit_attempts: remaining_submit_attempts,
        **extra,
      )
    end

    # @param [String] side the side of the image submission
    # @param [Integer] submit_attempts Times that user has tried submitting (previously called
    #   "attempts")
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [String] front_image_fingerprint Fingerprint of front image data
    # @param [String] back_image_fingerprint Fingerprint of back image data
    # @param [String] passport_image_fingerprint Fingerprint of back image data
    # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
    # @param ["Passport","DriversLicense"] document_type_requested Document user requested
    def idv_doc_auth_failed_image_resubmitted(
      side:,
      remaining_submit_attempts:,
      flow_path:,
      liveness_checking_required:,
      submit_attempts:,
      selfie_image_fingerprint: nil,
      front_image_fingerprint: nil,
      back_image_fingerprint: nil,
      passport_image_fingerprint: nil,
      document_type_requested: nil,
      **extra
    )
      track_event(
        'IdV: failed doc image resubmitted',
        side:,
        remaining_submit_attempts:,
        flow_path:,
        liveness_checking_required:,
        submit_attempts:,
        front_image_fingerprint:,
        back_image_fingerprint:,
        passport_image_fingerprint:,
        selfie_image_fingerprint:,
        document_type_requested:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [String] selection Selection form parameter
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_how_to_verify_submitted(
      success:,
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing: nil,
      selection: nil,
      error_details: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_how_to_verify_submitted,
        success:,
        error_details:,
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        selection:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_how_to_verify_visited(
      step:,
      analytics_id:,
      skip_hybrid_handoff:,
      opted_in_to_in_person_proofing: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_how_to_verify_visited,
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # The "hybrid handoff" step: Desktop user has submitted their choice to
    # either continue via desktop ("document_capture" destination) or switch
    # to mobile phone ("send_link" destination) to perform document upload.
    # @identity.idp.previous_event_name IdV: doc auth upload submitted
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
    #   warning
    # @param [Boolean] selfie_check_required Whether facial match check is required
    # @param ["document_capture","send_link"] destination Where user is sent after submission
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Hash] telephony_response Response from Telephony gem
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_hybrid_handoff_submitted(
      success:,
      errors:,
      step:,
      analytics_id:,
      redo_document_capture:,
      selfie_check_required:,
      destination:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      telephony_response: nil,
      **extra
    )
      track_event(
        'IdV: doc auth hybrid handoff submitted',
        success:,
        errors:,
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        selfie_check_required:,
        acuant_sdk_upgrade_ab_test_bucket:,
        opted_in_to_in_person_proofing:,
        destination:,
        flow_path:,
        telephony_response:,
        **extra,
      )
    end

    # Desktop user has reached the above "hybrid handoff" view
    # @identity.idp.previous_event_name IdV: doc auth upload visited
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] redo_document_capture Whether user is redoing document capture after barcode
    #   warning
    # @param [Boolean] selfie_check_required Whether facial match check is required
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_hybrid_handoff_visited(
      step:,
      analytics_id:,
      redo_document_capture:,
      selfie_check_required:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth hybrid handoff visited',
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        selfie_check_required:,
        acuant_sdk_upgrade_ab_test_bucket:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @identity.idp.previous_event_name IdV: doc auth send_link submitted
    def idv_doc_auth_link_sent_submitted(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth link_sent submitted',
        step:,
        analytics_id:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_link_sent_visited(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth link_sent visited',
        step:,
        analytics_id:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # Network error during doc auth image upload to vendor
    # @param [Integer] submit_attempts times the user has tried submitting
    # @param [Integer] remaining_submit_attempts attempts left before rate limit
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] vendor doc auth vendor that returned the error
    # @param [Hash] errors error hash from the vendor response
    # @param [String] exception exception message if one was raised
    def idv_doc_auth_network_error(
      submit_attempts:,
      remaining_submit_attempts:,
      flow_path:,
      vendor: nil,
      errors: nil,
      exception: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_network_error,
        submit_attempts:,
        remaining_submit_attempts:,
        flow_path:,
        vendor:,
        errors:,
        exception:,
        **extra,
      )
    end

    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
    def idv_doc_auth_redo_ssn_submitted(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      previous_ssn_edit_distance: nil,
      **extra
    )
      track_event(
        'IdV: doc auth redo_ssn submitted',
        step:,
        analytics_id:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        previous_ssn_edit_distance:,
        **extra,
      )
    end

    # User is shown the Socure timeout error page
    # @param [String] error_code The type of error that occurred
    # @param [Integer] remaining_submit_attempts The number of remaining attempts to submit
    # @param [String] docv_transaction_token The docvTransactionToken received from Socure
    # @param [Boolean] skip_hybrid_handoff Whether the user skipped the hybrid handoff A/B test
    # @param [Boolean] opted_in_to_in_person_proofing Whether the user opted into in-person proofing
    def idv_doc_auth_socure_error_visited(
      error_code:,
      remaining_submit_attempts:,
      docv_transaction_token: nil,
      skip_hybrid_handoff: nil,
      opted_in_to_in_person_proofing: nil,
      **extra
    )
      track_event(
        :idv_doc_auth_socure_error_visited,
        error_code:,
        remaining_submit_attempts:,
        docv_transaction_token:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # @param [String] created_at The created timestamp received from Socure
    # @param [String] customer_user_id The customerUserId received from Socure
    # @param [String] docv_transaction_token The docvTransactionToken received from Socure
    # @param [String] event_type The eventType received from Socure
    # @param [String] issuer The issuer of the Service Provider requesting IdV
    # @param [String] reference_id The referenceId received from Socure
    # @param [String] user_id The uuid of the user using Socure
    def idv_doc_auth_socure_webhook_received(
      created_at:,
      customer_user_id:,
      docv_transaction_token:,
      event_type:,
      issuer:,
      reference_id:,
      user_id:,
      **extra
    )
      track_event(
        :idv_doc_auth_socure_webhook_received,
        created_at:,
        customer_user_id:,
        docv_transaction_token:,
        event_type:,
        issuer:,
        reference_id:,
        user_id:,
        **extra,
      )
    end

    # User submits IdV Social Security number step
    # @identity.idp.previous_event_name IdV: in person proofing ssn submitted
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
    def idv_doc_auth_ssn_submitted(
      success:,
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      error_details: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      previous_ssn_edit_distance: nil,
      **extra
    )
      track_event(
        'IdV: doc auth ssn submitted',
        success:,
        error_details:,
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        previous_ssn_edit_distance:,
        **extra,
      )
    end

    # User visits IdV Social Security number step
    # @identity.idp.previous_event_name IdV: in person proofing ssn visited
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    # @param [Number] previous_ssn_edit_distance The edit distance to the previous submitted SSN
    def idv_doc_auth_ssn_visited(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      previous_ssn_edit_distance: nil,
      **extra
    )
      track_event(
        'IdV: doc auth ssn visited',
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        previous_ssn_edit_distance:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Integer] submit_attempts Times that user has tried submitting (previously called
    #   "attempts")
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param [String] user_id
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [String] front_image_fingerprint Fingerprint of front image data
    # @param [String] back_image_fingerprint Fingerprint of back image data
    # @param [String] passport_image_fingerprint Fingerprint of passport image data
    # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param ["Passport","DriversLicense"] document_type_requested Document capture user flow
    #   SDK upgrades
    # The document capture image uploaded was locally validated during the IDV process
    def idv_doc_auth_submitted_image_upload_form(
      success:,
      remaining_submit_attempts:,
      flow_path:,
      liveness_checking_required:,
      error_details: nil,
      submit_attempts: nil,
      user_id: nil,
      front_image_fingerprint: nil,
      back_image_fingerprint: nil,
      passport_image_fingerprint: nil,
      selfie_image_fingerprint: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      document_type_requested: nil,
      **extra
    )
      track_event(
        'IdV: doc auth image upload form submitted',
        success:,
        error_details:,
        submit_attempts:,
        remaining_submit_attempts:,
        user_id:,
        flow_path:,
        front_image_fingerprint:,
        back_image_fingerprint:,
        passport_image_fingerprint:,
        liveness_checking_required:,
        selfie_image_fingerprint:,
        acuant_sdk_upgrade_ab_test_bucket:,
        document_type_requested:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception
    # @param [Boolean] billed
    # @param [String] doc_auth_result
    # @param [String] state
    # @param [String] country for passport doc types
    # @param [String] document_type_received
    # @param [Boolean] async
    # @param [Integer] submit_attempts Times that user has tried submitting (previously called
    #   "attempts")
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param [Hash] client_image_metrics
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
    # @param [String] front_image_fingerprint Fingerprint of front image data
    # @param [String] back_image_fingerprint Fingerprint of back image data
    # @param [String] passport_image_fingerprint Fingerprint of back image data
    # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
    # @param [Boolean] attention_with_barcode Whether result was attention with barcode
    # @param [Boolean] doc_type_supported
    # @param [Boolean] doc_auth_success
    # @param [Boolean] liveness_checking_required Whether the selfie is required
    # @param [Boolean] liveness_enabled Whether the selfie result is included in response
    # @param [String] selfie_status
    # @param [String] vendor
    # @param [String] conversation_id
    # @param [String] request_id RequestId from TrueID
    # @param [String] reference
    # @param [String] transaction_status
    # @param [String] transaction_reason_code
    # @param [String] product_status
    # @param [String] decision_product_status
    # @param [Array] processed_alerts
    # @param [Integer] alert_failure_count
    # @param [Hash] log_alert_results
    # @param [Hash] portrait_match_results
    # @param [Hash] image_metrics
    # @param [Boolean] address_line2_present
    # @param [String] zip_code
    # @param [Boolean] selfie_live Selfie liveness result
    # @param [Boolean] selfie_quality_good Selfie quality result
    # @param [String] workflow LexisNexis TrueID workflow
    # @param [String] birth_year Birth year from document
    # @param [Integer] issue_year Year document was issued
    # @param [Hash] failed_image_fingerprints Hash of document field with an array of failed image
    #   fingerprints for that field.
    # @param [Integer] selfie_attempts number of selfie attempts the user currently has processed
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    #   SDK upgrades
    # @option extra [String] 'DocumentName'
    # @option extra [String] 'DocAuthResult'
    # @option extra [String] 'DocAuthTamperResult'
    # @option extra [String] 'DocAuthTamperSensitivity'
    # @option extra [String] 'DocIssuerCode'
    # @option extra [String] 'DocIssuerName'
    # @option extra [String] 'DocIssuerType'
    # @option extra [String] 'DocClassCode'
    # @option extra [String] 'DocClass'
    # @option extra [String] 'DocClassName'
    # @option extra [Boolean] 'DocIsGeneric'
    # @option extra [String] 'DocIssue'
    # @option extra [String] 'DocIssueType'
    # @option extra [String] 'ClassificationMode'
    # @option extra [Boolean] 'OrientationChanged'
    # @option extra [Boolean] 'PresentationChanged'
    # @param ["Passport","DriversLicense"] document_type_requested Document capture user flow
    # @param [Hash] passport_check_result The results of the Dos API call
    # @param [String] review_status The review status if the result was sent for review
    # The document capture image was uploaded to vendor during the IDV process
    def idv_doc_auth_submitted_image_upload_vendor(
      success:,
      errors:,
      exception:,
      document_type_received:,
      async:,
      submit_attempts:,
      remaining_submit_attempts:,
      client_image_metrics:,
      flow_path:,
      liveness_checking_required:,
      issue_year:,
      state: nil,
      country: nil,
      failed_image_fingerprints: nil,
      billed: nil,
      doc_auth_result: nil,
      vendor_request_time_in_ms: nil,
      front_image_fingerprint: nil,
      back_image_fingerprint: nil,
      passport_image_fingerprint: nil,
      selfie_image_fingerprint: nil,
      attention_with_barcode: nil,
      doc_type_supported: nil,
      doc_auth_success: nil,
      selfie_status: nil,
      vendor: nil,
      conversation_id: nil,
      request_id: nil,
      reference: nil,
      transaction_status: nil,
      transaction_reason_code: nil,
      product_status: nil,
      decision_product_status: nil,
      processed_alerts: nil,
      alert_failure_count: nil,
      log_alert_results: nil,
      portrait_match_results: nil,
      image_metrics: nil,
      address_line2_present: nil,
      zip_code: nil,
      selfie_live: nil,
      selfie_quality_good: nil,
      workflow: nil,
      birth_year: nil,
      selfie_attempts: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      liveness_enabled: nil,
      document_type_requested: nil,
      passport_check_result: nil,
      review_status: nil,
      **extra
    )
      track_event(
        'IdV: doc auth image upload vendor submitted',
        success:,
        errors:,
        exception:,
        billed:,
        doc_auth_result:,
        state:,
        country:,
        document_type_received:,
        async:,
        submit_attempts: submit_attempts,
        remaining_submit_attempts: remaining_submit_attempts,
        client_image_metrics:,
        flow_path:,
        vendor_request_time_in_ms:,
        front_image_fingerprint:,
        back_image_fingerprint:,
        passport_image_fingerprint:,
        selfie_image_fingerprint:,
        attention_with_barcode:,
        doc_type_supported:,
        doc_auth_success:,
        selfie_status:,
        vendor:,
        conversation_id:,
        request_id:,
        reference:,
        transaction_status:,
        transaction_reason_code:,
        product_status:,
        decision_product_status:,
        processed_alerts:,
        alert_failure_count:,
        log_alert_results:,
        portrait_match_results:,
        image_metrics:,
        address_line2_present:,
        liveness_checking_required:,
        zip_code:,
        selfie_live:,
        selfie_quality_good:,
        workflow:,
        birth_year:,
        issue_year:,
        failed_image_fingerprints:,
        selfie_attempts:,
        acuant_sdk_upgrade_ab_test_bucket:,
        liveness_enabled:,
        document_type_requested:,
        passport_check_result:,
        review_status:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] user_id
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # @param [String] document_type_received Document type detected by the vendor
    # @param ["present","missing"] id_issued_status Status of state_id_issued field presence
    # @param ["present","missing"] id_expiration_status Status of state_id_expiration field presence
    # @param ["present","missing"] passport_issued_status Status of passport_issued field presence
    # @param ["present","missing"] passport_expiration_status Status of passport_expiration field
    # @param [Boolean] attention_with_barcode Whether result was attention with barcode
    # @param [Integer] submit_attempts Times that user has tried submitting
    # @param [String] front_image_fingerprint Fingerprint of front image data
    # @param [String] back_image_fingerprint Fingerprint of back image data
    # @param [String] passport_image_fingerprint Fingerprint of back image data
    # @param [String] selfie_image_fingerprint Fingerprint of selfie image data
    # @param ["Passport","DriversLicense"] document_type_requested Document capture user flow
    # @param [Hash] classification_info document image side information, issuing country and type etc
    # The PII that came back from the document capture vendor was validated
    def idv_doc_auth_submitted_pii_validation(
      success:,
      remaining_submit_attempts:,
      flow_path:,
      liveness_checking_required:,
      attention_with_barcode:,
      document_type_received:,
      id_issued_status:,
      id_expiration_status:,
      passport_issued_status:,
      passport_expiration_status:,
      submit_attempts:,
      errors: nil,
      error_details: nil,
      user_id: nil,
      front_image_fingerprint: nil,
      back_image_fingerprint: nil,
      passport_image_fingerprint: nil,
      selfie_image_fingerprint: nil,
      classification_info: nil,
      document_type_requested: nil,
      **extra
    )
      track_event(
        'IdV: doc auth image upload vendor pii validation',
        success:,
        errors:,
        error_details:,
        user_id:,
        attention_with_barcode:,
        document_type_received:,
        id_issued_status:,
        id_expiration_status:,
        passport_issued_status:,
        passport_expiration_status:,
        submit_attempts:,
        remaining_submit_attempts:,
        flow_path:,
        front_image_fingerprint:,
        back_image_fingerprint:,
        passport_image_fingerprint:,
        selfie_image_fingerprint:,
        classification_info:,
        liveness_checking_required:,
        document_type_requested:,
        **extra,
      )
    end

    # User visits IdV verify step waiting on a resolution proofing job result
    # @identity.idp.previous_event_name IdV: doc auth verify visited
    def idv_doc_auth_verify_polling_wait_visited(**extra)
      track_event(:idv_doc_auth_verify_polling_wait_visited, **extra)
    end

    # rubocop:disable Layout/LineLength
    # @param ab_tests [Hash] Object that holds A/B test data (legacy A/B tests may include attributes outside the scope of this object)
    # @param acuant_sdk_upgrade_ab_test_bucket [String] A/B test bucket for Acuant document capture SDK upgrades
    # @param address_edited [Boolean] Whether the user edited their address before submitting the "Verify your information" step
    # @param address_line2_present [Boolean] Whether the user's address includes a second address line
    # @param analytics_id [String] "Doc Auth" for remote unsupervised, "In Person Proofing" for IPP
    # @param errors [Hash] Details about vendor-specific errors encountered during the stages of the identity resolution process
    # @param flow_path [String] "hybrid" for hybrid handoff, "standard" otherwise
    # @param last_name_spaced [Boolean] Whether the user's last name includes an empty space
    # @param lexisnexis_instant_verify_workflow_ab_test_bucket [String] A/B test bucket for Lexis Nexis InstantVerify workflow testing
    # @param opted_in_to_in_person_proofing [Boolean] Whether this user explicitly opted into in-person proofing
    # @param proofing_results [Hash]
    # @option proofing_results [String,nil] exception If an exception occurred during any phase of proofing its message is provided here
    # @option proofing_results [Boolean] timed_out true if any vendor API calls timed out during proofing
    # @option proofing_results [String] threatmetrix_review_status Result of Threatmetrix assessment, either "review", "reject", or "pass"
    # @option proofing_results [Hash] context Full context of the proofing process
    # @option proofing_results [String] context.device_profiling_adjudication_reason Reason code describing how we arrived at the device profiling result
    # @option proofing_results [String] context.resolution_adjudication_reason Reason code describing how we arrived at the identity resolution result
    # @option proofing_results [Boolean] context.should_proof_state_id Whether we need to verify the user's PII with AAMVA. False if the user is using a document from a non-AAMVA jurisdiction
    # @option proofing_results [Hash] context.stages Object holding details about each stage of the proofing process
    # @option proofing_results [Hash] context.stages.resolution Object holding details about the call made to the identity resolution vendor
    # @option proofing_results [Boolean] context.stages.resolution.success Whether identity resolution proofing was successful
    # @option proofing_results [Hash] context.stages.resolution.errors Object describing errors encountered during identity resolution
    # @option proofing_results [String,nil] context.stages.resolution.exception If an exception occured during identity resolution its message is provided here
    # @option proofing_results [Boolean] context.stages.resolution.timed_out Whether the identity resolution API request timed out
    # @option proofing_results [String] context.stages.resolution.transaction_id A unique id for the underlying vendor request
    # @option proofing_results [Boolean] context.stages.resolution.can_pass_with_additional_verification Whether the PII could be verified if another vendor verified certain attributes
    # @option proofing_results [Array<String>] context.stages.resolution.attributes_requiring_additional_verification Attributes that need to be verified by another vendor
    # @option proofing_results [Array<String>,nil] context.stages.resolution.source_attribution List of sources that contributed to the resolution proofing result
    # @option proofing_results [String,nil] context.stages.resolution.vendor_id Vendor's internal ID for resolution proofing requests, e.g. socureId
    # @option proofing_results [String] context.stages.resolution.vendor_name Vendor used (e.g. lexisnexis:instant_verify)
    # @option proofing_results [String] context.stages.resolution.vendor_workflow ID of workflow or configuration the vendor used for this transaction
    # @option proofing_results [Boolean] context.stages.residential_address.success Whether the residential address passed proofing
    # @option proofing_results [Hash] context.stages.residential_address.errors Object holding error details returned by the residential address proofing vendor.
    # @option proofing_results [String,nil] context.stages.residential_address.exception If an exception occured during residential address verification its message is provided here
    # @option proofing_results [Boolean] context.stages.residential_address.timed_out True if the request to the residential address proofing vendor timed out
    # @option proofing_results [String] context.stages.residential_address.transaction_id Vendor-specific transaction ID for the request made to the residential address proofing vendor
    # @option proofing_results [Boolean] context.stages.residential_address.can_pass_with_additional_verification Whether, if residential address proofing failed, it could pass with additional proofing from another vendor
    # @option proofing_results [Array<String>,nil] context.stages.residential_address.attributes_requiring_additional_verification List of PII attributes that require additional verification for residential address proofing to pass
    # @option proofing_results [Array<String>,nil] context.stages.residential_address.source_attribution List of sources that contributed to the residential address proofing result
    # @option proofing_results [String,nil] context.stages.residential_address.vendor_id Vendor's internal ID for residential address proofing requests, e.g. socureId
    # @option proofing_results [String] context.stages.residential_address.vendor_name Vendor used for residential address proofing
    # @option proofing_results [String] context.stages.residential_address.vendor_workflow Vendor-specific workflow or configuration ID associated with the request made.
    # @option proofing_results [Hash] context.stages.threatmetrix Object holding details about the call made to the device profiling vendor
    # @option proofing_results [String] context.stages.threatmetrix.client Identifier string indicating which client was used.
    # @option proofing_results [Boolean] context.stages.threatmetrix.success Whether the request to the vendor succeeded.
    # @option proofing_results [Hash] context.stages.threatmetrix.errors Hash describing errors encountered when making the request.
    # @option proofing_results [String,nil] context.stages.threatmetrix.exception If an exception was encountered making the request to the vendor, its message is provided here.
    # @option proofing_results [Boolean] context.stages.threatmetrix.timed_out Whether the request to the vendor timed out.
    # @option proofing_results [String] context.stages.threatmetrix.transaction_id Vendor-specific transaction ID for the request.
    # @option proofing_results [String] context.stages.threatmetrix.session_id Session ID associated with the response.
    # @option proofing_results [String] context.stages.threatmetrix.account_lex_id LexID associated with the response.
    # @option proofing_results [Hash] context.stages.threatmetrix.response_body JSON body of the response returned from the vendor. PII has been redacted.
    # @option proofing_results [String] context.stages.threatmetrix.review_status One of "pass", "review", "reject".
    # @param skip_hybrid_handoff [Boolean] Whether the user should skip hybrid handoff (i.e. because they are already on a mobile device)
    # @param ssn_is_unique [Boolean] Whether another Profile existed with the same SSN at the time the profile associated with the current IdV session was minted.
    # @param step [String] Always "verify" (leftover from flow state machine days)
    # @param success [Boolean] Whether identity resolution succeeded overall
    # @param previous_ssn_edit_distance [Number] The edit distance to the previous submitted SSN
    # @param exceptions [Hash, nil] The exceptions found in the proofing results.
    def idv_doc_auth_verify_proofing_results(
      ab_tests: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      address_edited: nil,
      address_line2_present: nil,
      analytics_id: nil,
      errors: nil,
      flow_path: nil,
      last_name_spaced: nil,
      lexisnexis_instant_verify_workflow_ab_test_bucket: nil,
      opted_in_to_in_person_proofing: nil,
      proofing_results: nil,
      skip_hybrid_handoff: nil,
      ssn_is_unique: nil,
      step: nil,
      success: nil,
      previous_ssn_edit_distance: nil,
      exceptions: nil,
      **extra
    )
      track_event(
        'IdV: doc auth verify proofing results',
        ab_tests:,
        acuant_sdk_upgrade_ab_test_bucket:,
        address_edited:,
        address_line2_present:,
        analytics_id:,
        errors:,
        flow_path:,
        lexisnexis_instant_verify_workflow_ab_test_bucket:,
        last_name_spaced:,
        opted_in_to_in_person_proofing:,
        proofing_results:,
        skip_hybrid_handoff:,
        ssn_is_unique:,
        step:,
        success:,
        previous_ssn_edit_distance:,
        exceptions:,
        **extra,
      )
    end

    # User submits IdV verify step
    # @identity.idp.previous_event_name IdV: in person proofing verify submitted
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_verify_submitted(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth verify submitted',
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # User visits IdV verify step
    # @identity.idp.previous_event_name IdV: in person proofing verify visited
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] acuant_sdk_upgrade_ab_test_bucket A/B test bucket for Acuant document capture
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_verify_visited(
      step:,
      analytics_id:,
      flow_path:,
      opted_in_to_in_person_proofing: nil,
      acuant_sdk_upgrade_ab_test_bucket: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth verify visited',
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        acuant_sdk_upgrade_ab_test_bucket:,
        flow_path:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # @param [String] step_name
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # The user was sent to a warning page during the IDV flow
    def idv_doc_auth_warning_visited(step_name:, remaining_submit_attempts:, **extra)
      track_event(
        'IdV: doc auth warning visited',
        step_name: step_name,
        remaining_submit_attempts: remaining_submit_attempts,
        **extra,
      )
    end

    # User submits IdV welcome screen
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_welcome_submitted(
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth welcome submitted',
        step:,
        analytics_id:,
        opted_in_to_in_person_proofing:,
        skip_hybrid_handoff:,
        **extra,
      )
    end

    # User visits IdV welcome screen
    # @param [String] step Current IdV step
    # @param [String] analytics_id Current IdV flow identifier
    # @param [Boolean] skip_hybrid_handoff Whether skipped hybrid handoff A/B test is active
    # @param [Boolean] opted_in_to_in_person_proofing User opted into in person proofing
    def idv_doc_auth_welcome_visited(
      step:,
      analytics_id:,
      opted_in_to_in_person_proofing: nil,
      skip_hybrid_handoff: nil,
      **extra
    )
      track_event(
        'IdV: doc auth welcome visited',
        step:,
        analytics_id:,
        skip_hybrid_handoff:,
        opted_in_to_in_person_proofing:,
        **extra,
      )
    end

    # User's passport information submitted to DoS for validation
    # @param [Boolean] success Whether the validation succeeded
    # @param [String] response The raw verdict from DoS
    # @param [Integer] submit_attempts Times that user has tried submitting document capture
    # @param [Integer] remaining_submit_attempts  how many attempts the user has left before
    #                  we rate limit them.
    # @param [String] document_type_requested The document type requested by user
    # @param [String] correlation_id_received The correlation ID received in the response
    # @param [String] correlation_id_sent The correlation ID sent in the request
    # @param [String] exception The exception message if an exception occurred
    # @param [String] error_code The error code if provided in a failed response
    # @param [String] error_message The error message if provided in a failed response
    # @param [String] error_reason The error reason if provided in a failed response
    # @param [String] errors The DocAuth response error for failure
    def idv_dos_passport_verification(
      success:,
      submit_attempts:,
      remaining_submit_attempts:,
      document_type_requested:,
      response: nil,
      correlation_id_received: nil,
      correlation_id_sent: nil,
      exception: nil,
      error_code: nil,
      error_message: nil,
      error_reason: nil,
      errors: nil,
      **extra
    )
      track_event(
        :idv_dos_passport_verification,
        success:,
        response:,
        submit_attempts:,
        remaining_submit_attempts:,
        document_type_requested:,
        correlation_id_sent:,
        correlation_id_received:,
        error_code:,
        error_message:,
        error_reason:,
        errors:,
        exception:,
        **extra,
      )
    end

    # @param [String] acuantCaptureMode
    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param [Boolean] assessment
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [String] documentType
    # @param [Integer] dpi  dots per inch of image
    # @param [Integer] failedImageResubmission
    # @param [String] fingerprint fingerprint of the image added
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Integer] glare
    # @param [Integer] glareScoreThreshold
    # @param [Integer] height height of image added in pixels
    # @param [Boolean] isAssessedAsBlurry
    # @param [Boolean] isAssessedAsGlare
    # @param [Boolean] isAssessedAsUnsupported
    # @param [String] mimeType MIME type of image added
    # @param [Integer] moire
    # @param [Integer] sharpness
    # @param [Integer] sharpnessScoreThreshold
    # @param [Integer] size size of image added in bytes
    # @param [String] source
    # @param [Boolean] use_alternate_sdk
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [Integer] width width of image added in pixels
    # Front image was added in document capture
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_front_image_added(
      acuantCaptureMode:,
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      assessment:,
      captureAttempts:,
      documentType:,
      dpi:,
      failedImageResubmission:,
      fingerprint:,
      flow_path:,
      glare:,
      glareScoreThreshold:,
      height:,
      isAssessedAsBlurry:,
      isAssessedAsGlare:,
      isAssessedAsUnsupported:,
      mimeType:,
      moire:,
      sharpness:,
      sharpnessScoreThreshold:,
      size:,
      source:,
      use_alternate_sdk:,
      liveness_checking_required:,
      width:,
      **extra
    )
      track_event(
        'Frontend: IdV: front image added',
        acuantCaptureMode: acuantCaptureMode,
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        assessment: assessment,
        captureAttempts: captureAttempts,
        documentType: documentType,
        dpi: dpi,
        failedImageResubmission: failedImageResubmission,
        fingerprint: fingerprint,
        flow_path: flow_path,
        glare: glare,
        glareScoreThreshold: glareScoreThreshold,
        height: height,
        isAssessedAsBlurry: isAssessedAsBlurry,
        isAssessedAsGlare: isAssessedAsGlare,
        isAssessedAsUnsupported: isAssessedAsUnsupported,
        mimeType: mimeType,
        moire: moire,
        sharpness: sharpness,
        sharpnessScoreThreshold: sharpnessScoreThreshold,
        size: size,
        source: source,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        width: width,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] isDrop
    # @param [String] click_source
    # @param [String] use_alternate_sdk
    # @param [Number] captureAttempts count of image capturing attempts
    # @param [Boolean] liveness_checking_required
    def idv_front_image_clicked(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      isDrop:,
      click_source:,
      use_alternate_sdk:,
      captureAttempts:,
      liveness_checking_required: nil,
      **extra
    )
      track_event(
        'Frontend: IdV: front image clicked',
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        isDrop: isDrop,
        click_source: click_source,
        use_alternate_sdk: use_alternate_sdk,
        liveness_checking_required: liveness_checking_required,
        captureAttempts: captureAttempts,
        **extra,
      )
    end

    # @param [String] field back or front
    # @param [String] acuantCaptureMode
    # @param [String] error
    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] use_alternate_sdk
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_image_capture_failed(
      field:,
      acuantCaptureMode:,
      error:,
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      use_alternate_sdk:,
      **extra
    )
      track_event(
        'Frontend: IdV: Image capture failed',
        field: field,
        acuantCaptureMode: acuantCaptureMode,
        error: error,
        acuant_sdk_upgrade_a_b_testing_enabled: acuant_sdk_upgrade_a_b_testing_enabled,
        acuant_version: acuant_version,
        flow_path: flow_path,
        use_alternate_sdk: use_alternate_sdk,
        **extra,
      )
    end

    # @param [Boolean] isCancelled
    # @param [Boolean] isRateLimited
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_link_sent_capture_doc_polling_complete(
      isCancelled:,
      isRateLimited:,
      **extra
    )
      track_event(
        'Frontend: IdV: Link sent capture doc polling complete',
        isCancelled: isCancelled,
        isRateLimited: isRateLimited,
        **extra,
      )
    end

    def idv_link_sent_capture_doc_polling_started(**extra)
      track_event(
        'Frontend: IdV: Link sent capture doc polling started',
        **extra,
      )
    end

    # @param [Integer] failed_capture_attempts Number of failed Acuant SDK attempts
    # @param [Integer] failed_submission_attempts Number of failed Acuant doc submissions
    # @param [String] field Image form field
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # The number of acceptable failed attempts (maxFailedAttemptsBeforeNativeCamera) has been met
    # or exceeded, and the system has forced the use of the native camera, rather than Acuant's
    # camera, on mobile devices.
    def idv_native_camera_forced(
      failed_capture_attempts:,
      failed_submission_attempts:,
      field:,
      flow_path:,
      **extra
    )
      track_event(
        'IdV: Native camera forced after failed attempts',
        failed_capture_attempts: failed_capture_attempts,
        failed_submission_attempts: failed_submission_attempts,
        field: field,
        flow_path: flow_path,
        **extra,
      )
    end

    # @param [String] acuantCaptureMode
    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param [Boolean] assessment
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [String] documentType
    # @param [Integer] dpi  dots per inch of image
    # @param [Integer] failedImageResubmission
    # @param [String] fingerprint fingerprint of the image added
    # @param [String] flow_path whether the user is in the hybrid or standard flow
    # @param [Integer] glare
    # @param [Integer] glareScoreThreshold
    # @param [Integer] height height of image added in pixels
    # @param [Boolean] isAssessedAsBlurry
    # @param [Boolean] isAssessedAsGlare
    # @param [Boolean] isAssessedAsUnsupported
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [String] mimeType MIME type of image added
    # @param [Integer] moire
    # @param [Integer] sharpness
    # @param [Integer] sharpnessScoreThreshold
    # @param [Integer] size size of image added in bytes
    # @param [String] source
    # @param [Boolean] use_alternate_sdk
    # @param [Integer] width width of image added in pixels
    # Back image was added in document capture
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName,IdentityIdp/AnalyticsEventNameLinter
    def idv_passport_image_added(
      acuantCaptureMode:,
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      assessment:,
      captureAttempts:,
      documentType:,
      dpi:,
      failedImageResubmission:,
      fingerprint:,
      flow_path:,
      glare:,
      glareScoreThreshold:,
      height:,
      isAssessedAsBlurry:,
      isAssessedAsGlare:,
      isAssessedAsUnsupported:,
      liveness_checking_required:,
      mimeType:,
      moire:,
      sharpness:,
      sharpnessScoreThreshold:,
      size:,
      source:,
      use_alternate_sdk:,
      width:,
      **extra
    )
      track_event(
        'Frontend: IdV: passport image added',
        acuantCaptureMode:,
        acuant_sdk_upgrade_a_b_testing_enabled:,
        acuant_version:,
        assessment:,
        captureAttempts:,
        documentType:,
        dpi:,
        failedImageResubmission:,
        fingerprint:,
        flow_path:,
        glare:,
        glareScoreThreshold:,
        height:,
        isAssessedAsBlurry:,
        isAssessedAsGlare:,
        isAssessedAsUnsupported:,
        liveness_checking_required:,
        mimeType:,
        moire:,
        sharpness:,
        sharpnessScoreThreshold:,
        size:,
        source:,
        use_alternate_sdk:,
        width:,
        **extra,
      )
    end

    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param [Number] captureAttempts count of image capturing attempts
    # @param [Boolean] click_source
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] isDrop
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [Boolean] use_alternate_sdk
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName,IdentityIdp/AnalyticsEventNameLinter
    def idv_passport_image_clicked(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      captureAttempts:,
      click_source:,
      flow_path:,
      isDrop:,
      liveness_checking_required:,
      use_alternate_sdk:,
      **extra
    )
      track_event(
        'Frontend: IdV: passport image clicked',
        acuant_sdk_upgrade_a_b_testing_enabled:,
        acuant_version:,
        captureAttempts:,
        click_source:,
        flow_path:,
        isDrop:,
        liveness_checking_required:,
        use_alternate_sdk:,
        **extra,
      )
    end

    # Acuant SDK errored after loading but before initialization
    # @param [Boolean] success
    # @param [String] error_message
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_sdk_error_before_init(
      success:,
      error_message:,
      liveness_checking_required:,
      acuant_version:,
      captureAttempts: nil,
      **extra
    )
      track_event(
        :idv_sdk_error_before_init,
        success:,
        error_message: error_message,
        liveness_checking_required:,
        acuant_version: acuant_version,
        captureAttempts: captureAttempts,
        **extra,
      )
    end

    # User closed the SDK for taking a selfie without submitting a photo
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_sdk_selfie_image_capture_closed_without_photo(
      acuant_version:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_capture_closed_without_photo,
        acuant_version:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # User encountered an error with the SDK selfie process
    #   Error code 1: camera permission not granted
    #   Error code 2: unexpected errors
    # @param [String] acuant_version
    # @param [Integer] sdk_error_code SDK code for the error encountered
    # @param [String] sdk_error_message SDK message for the error encountered
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_sdk_selfie_image_capture_failed(
      acuant_version:,
      sdk_error_code:,
      sdk_error_message:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_capture_failed,
        acuant_version:,
        sdk_error_code:,
        sdk_error_message:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # Camera is ready to detect face for capturing selfie
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    def idv_sdk_selfie_image_capture_initialized(
      acuant_version:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_capture_initialized,
        acuant_version:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # User opened the SDK to take a selfie
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_sdk_selfie_image_capture_opened(
      acuant_version:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_capture_opened,
        acuant_version:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # User opened the SDK to take a selfie
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    # @param [Integer] selfie_attempts number of selfie captured by SDK
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    def idv_sdk_selfie_image_re_taken(
      acuant_version:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_re_taken,
        acuant_version:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # User opened the SDK to take a selfie
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    # @param [Integer] selfie_attempts number of selfie captured by SDK
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    def idv_sdk_selfie_image_taken(
      acuant_version:,
      captureAttempts: nil,
      selfie_attempts: nil,
      liveness_checking_required: true, # default to true to facilitate CW filtering
      **extra
    )
      track_event(
        :idv_sdk_selfie_image_taken,
        acuant_version:,
        captureAttempts:,
        selfie_attempts:,
        liveness_checking_required:,
        **extra,
      )
    end

    # User took a selfie image with the SDK, or uploaded a selfie using the file picker
    # @param [String] acuant_version
    # @param [Integer] captureAttempts number of attempts to capture / upload an image
    #                  (previously called "attempt")
    # @param [Integer] selfie_attempts number of times SDK captured selfie, user may decide to retake
    # @param [Integer] failedImageResubmission
    # @param [String] fingerprint fingerprint of the image added
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Integer] height height of image added in pixels
    # @param [String] mimeType MIME type of image added
    # @param [Integer] size size of image added in bytes
    # @param [String] source
    # @param [String] liveness_checking_required Whether or not the selfie is required
    # @param [Integer] width width of image added in pixels
    # rubocop:disable Naming/VariableName,Naming/MethodParameterName
    def idv_selfie_image_added(
      acuant_version:,
      captureAttempts:,
      selfie_attempts:,
      failedImageResubmission:,
      fingerprint:,
      flow_path:,
      height:,
      mimeType:,
      size:,
      source:,
      liveness_checking_required:,
      width:,
      **extra
    )
      track_event(
        :idv_selfie_image_added,
        acuant_version: acuant_version,
        captureAttempts: captureAttempts,
        selfie_attempts: selfie_attempts,
        failedImageResubmission: failedImageResubmission,
        fingerprint: fingerprint,
        flow_path: flow_path,
        height: height,
        mimeType: mimeType,
        size: size,
        source: source,
        liveness_checking_required: liveness_checking_required,
        width: width,
        **extra,
      )
    end

    # rubocop:disable Naming/VariableName,Naming/MethodParameterName,
    # @param [Boolean] acuant_sdk_upgrade_a_b_testing_enabled
    # @param [String] acuant_version
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Boolean] isDrop
    # @param [String] click_source
    # @param [String] use_alternate_sdk
    # @param [Number] captureAttempts
    # @param [Boolean] liveness_checking_required
    # @param [Hash,nil] proofing_components User's proofing components.
    # @param [String,nil] active_profile_idv_level ID verification level of user's active profile.
    # @param [String,nil] pending_profile_idv_level ID verification level of user's pending profile.
    def idv_selfie_image_clicked(
      acuant_sdk_upgrade_a_b_testing_enabled:,
      acuant_version:,
      flow_path:,
      isDrop:,
      click_source:,
      use_alternate_sdk:,
      captureAttempts:,
      liveness_checking_required: nil,
      proofing_components: nil,
      active_profile_idv_level: nil,
      pending_profile_idv_level: nil,
      **extra
    )
      track_event(
        :idv_selfie_image_clicked,
        acuant_sdk_upgrade_a_b_testing_enabled:,
        acuant_version:,
        flow_path:,
        isDrop:,
        click_source:,
        use_alternate_sdk:,
        captureAttempts:,
        liveness_checking_required:,
        proofing_components:,
        active_profile_idv_level:,
        pending_profile_idv_level:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception any exceptions thrown during request
    # @param [String] docv_transaction_token socure transaction token
    # @param [String] reference_id socure interal id for transaction
    # @param [String] customer_user_id user uuid sent to socure
    # @param [String] language lagnuage presented to user
    # @param [String] step current step of idv to user
    # @param [String] analytics_id id of analytics
    # @param [Boolean] redo_document_capture if user is redoing doc capture
    # @param [Boolean] skip_hybrid_handoff if user is skipping handoff
    # @param [Boolean] selfie_check_required is selfie check required
    # @param [Boolean] opted_in_to_in_person_proofing user opts in to IPP
    # @param [Hash] redirect hash for redirect (url and method)
    # @param [Hash] response_body hash received from socure
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
    # @param [Boolean] liveness_checking_required Whether or not the selfie is required
    # @param [Boolean] liveness_enabled Whether or not the selfie result is included in response
    # @param [String] vendor which 2rd party we are using for doc auth
    # @param [Hash] document_type_requested type of socument submitted (Drivers Licenese, etc.)
    # @param [String] socure_status Socure's status value for internal errors on their side.
    # @param [String] socure_msg Socure's status message for interal errors on their side.
    # @param [String] use_case_key name of requested DocV flow
    # The request for socure verification was sent
    def idv_socure_document_request_submitted(
      success:,
      redirect:,
      liveness_checking_required:,
      vendor_request_time_in_ms:,
      vendor:,
      language:,
      step:,
      analytics_id:,
      response_body:,
      redo_document_capture: nil,
      skip_hybrid_handoff: nil,
      selfie_check_required: nil,
      opted_in_to_in_person_proofing: nil,
      errors: nil,
      exception: nil,
      reference_id: nil,
      customer_user_id: nil,
      liveness_enabled: nil,
      document_type_requested: nil,
      docv_transaction_token: nil,
      flow_path: nil,
      socure_status: nil,
      socure_msg: nil,
      use_case_key: nil,
      **extra
    )
      track_event(
        :idv_socure_document_request_submitted,
        success:,
        redirect:,
        liveness_checking_required:,
        vendor_request_time_in_ms:,
        vendor:,
        language:,
        step:,
        analytics_id:,
        redo_document_capture:,
        skip_hybrid_handoff:,
        selfie_check_required:,
        opted_in_to_in_person_proofing:,
        errors:,
        exception:,
        reference_id:,
        customer_user_id:,
        response_body:,
        liveness_enabled:,
        document_type_requested:,
        docv_transaction_token:,
        flow_path:,
        socure_status:,
        socure_msg:,
        use_case_key:,
        **extra,
      )
    end

    # Socure KYC API was called with the following results
    # @param [Boolean] success Result from Socure KYC API call
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
    def idv_socure_kyc_results(
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
        :idv_socure_kyc_results,
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

    # Socure Reason Codes were downloaded and synced against persisted codes in the database
    # @param [Boolean] success Result from Socure KYC API call
    # @param [Hash] errors Result from resolution proofing
    # @param [String] exception Exception that occured during download or synchronizaiton
    # @param [Array] added_reason_codes New reason codes that were added to the database
    # @param [Array] deactivated_reason_codes Old reason codes that were deactivated
    def idv_socure_reason_code_download(
      success: true,
      errors: nil,
      exception: nil,
      added_reason_codes: nil,
      deactivated_reason_codes: nil,
      **extra
    )
      track_event(
        :idv_socure_reason_code_download,
        success:,
        errors:,
        exception:,
        added_reason_codes:,
        deactivated_reason_codes:,
        **extra,
      )
    end

    # Logs a Socure Phone Risk result alongside a address proofing result for later comparison.
    # @param [Hash] socure_result Result from Socure PhoneRisk API call
    # @param [Hash] phone_result Result from address proofing
    # @param [String,nil] phone_source Whether the phone number is from MFA or hybrid handoff
    def idv_socure_shadow_mode_phonerisk_result(
      socure_result:,
      phone_result:,
      phone_source:,
      **extra
    )
      track_event(
        :idv_socure_shadow_mode_phonerisk_result,
        phone_result: phone_result.to_h,
        phone_source:,
        socure_result: socure_result.to_h,
        **extra,
      )
    end

    # Indicates that no result was found when SocureShadowModePhoneRiskJob
    # attempted to look for one.
    def idv_socure_shadow_mode_phonerisk_result_missing(**extra)
      track_event(:idv_socure_shadow_mode_phonerisk_result_missing, **extra)
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] errors Errors resulting from form validation
    # @param [String] exception
    # @param [Boolean] address_line2_present wether or not we have an address that uses the 2nd line
    # @param [Boolean] async whether this worker is running asynchronously
    # @param [Boolean] billed
    # @param [String] birth_year Birth year from document
    # @param [String] expiration_date Expiration date from document
    # @param [Hash] customer_profile socure customer profile
    # @param [String] customer_user_id user uuid sent to Socure
    # @param [Hash] decision accept or reject of given ID
    # @param [Boolean] doc_auth_success
    # @param [Boolean] doc_type_supported
    # @param [Hash] document_metadata Data about the document that was submitted
    # @option document_metadata [String] 'country' Country that issued the document
    # @option document_metadata [String] 'state' State that issued the document
    # @option document_metadata [String] 'type' Type of document submitted (Drivers License, etc.)
    # @param [String] docv_transaction_token socure transaction token
    # @param ["hybrid","standard"] flow_path Document capture user flow
    # @param [String] document_type_received type of state issued ID or passport
    # @param [Integer] issue_year Year document was issued
    # @param [String] issuer The issuer of the Service Provider requesting IdV
    # @param [Boolean] liveness_enabled Whether the selfie result is included in response
    # @param [Hash] reason_codes socure internal reason codes for accept reject decision
    # @param [String] reference_id socure internal id for transaction
    # @param [Integer] remaining_submit_attempts (previously called "remaining_attempts")
    # @param [String] state state of ID
    # @param [Integer] submit_attempts Times that user has tried submitting (previously called
    # @param [String] user_id internal id of socure user
    #   "attempts")
    # @param [String] vendor which 2rd party we are using for doc auth
    # @param [Float] vendor_request_time_in_ms Time it took to upload images & get a response.
    # @param [String] vendor_status Socure's request status (used for errors)
    # @param [String] vendor_status_message socure's error message (used for errors)
    # @param [String] zip_code zip code from state issued ID
    # The request for socure verification was sent
    def idv_socure_verification_data_requested(
      success:,
      errors:,
      async:,
      doc_type_supported:,
      doc_auth_success:,
      remaining_submit_attempts:,
      submit_attempts:,
      vendor:,
      vendor_request_time_in_ms:,
      exception: nil,
      address_line2_present: nil,
      billed: nil,
      birth_year: nil,
      customer_profile: nil,
      customer_user_id: nil,
      decision: nil,
      document_metadata: nil,
      docv_transaction_token: nil,
      expiration_date: nil,
      flow_path: nil,
      document_type_received: nil,
      issue_year: nil,
      issuer: nil,
      liveness_enabled: nil,
      reference_id: nil,
      reason_codes: nil,
      state: nil,
      user_id: nil,
      vendor_status: nil,
      vendor_status_message: nil,
      zip_code: nil,
      **extra
    )
      track_event(
        :idv_socure_verification_data_requested,
        success:,
        errors:,
        exception:,
        address_line2_present:,
        async:,
        billed:,
        birth_year:,
        customer_profile:,
        customer_user_id:,
        decision:,
        doc_auth_success:,
        doc_type_supported:,
        document_metadata:,
        docv_transaction_token:,
        expiration_date:,
        flow_path:,
        document_type_received:,
        issue_year:,
        issuer:,
        liveness_enabled:,
        reason_codes:,
        reference_id:,
        remaining_submit_attempts:,
        state:,
        submit_attempts:,
        user_id:,
        vendor:,
        vendor_request_time_in_ms:,
        vendor_status:,
        vendor_status_message:,
        zip_code:,
        **extra,
      )
    end

    # @param [String] docv_transaction_token The docvTransactionToken received from Socure
    def idv_socure_verification_webhook_missing(docv_transaction_token: nil, **extra)
      track_event(
        :idv_socure_verification_webhook_missing,
        docv_transaction_token:,
        **extra,
      )
    end
  end
end
