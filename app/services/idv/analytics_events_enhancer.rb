module Idv
  module AnalyticsEventsEnhancer
    IGNORED_METHODS = %i[
      idv_acuant_sdk_loaded
      idv_address_submitted
      idv_address_visit
      idv_back_image_added
      idv_back_image_clicked
      idv_barcode_warning_continue_clicked
      idv_barcode_warning_retake_photos_clicked
      idv_capture_troubleshooting_dismissed
      idv_consent_checkbox_toggled
      idv_doc_auth_agreement_submitted
      idv_doc_auth_agreement_visited
      idv_doc_auth_capture_complete_visited
      idv_doc_auth_document_capture_submitted
      idv_doc_auth_document_capture_visited
      idv_doc_auth_exception_visited
      idv_doc_auth_failed_image_resubmitted
      idv_doc_auth_how_to_verify_submitted
      idv_doc_auth_how_to_verify_visited
      idv_doc_auth_hybrid_handoff_submitted
      idv_doc_auth_hybrid_handoff_visited
      idv_doc_auth_link_sent_submitted
      idv_doc_auth_link_sent_visited
      idv_doc_auth_randomizer_defaulted
      idv_doc_auth_redo_ssn_submitted
      idv_doc_auth_ssn_submitted
      idv_doc_auth_ssn_visited
      idv_doc_auth_submitted_image_upload_form
      idv_doc_auth_submitted_image_upload_vendor
      idv_doc_auth_submitted_pii_validation
      idv_doc_auth_verify_proofing_results
      idv_doc_auth_verify_submitted
      idv_doc_auth_verify_visited
      idv_doc_auth_warning_visited
      idv_doc_auth_welcome_submitted
      idv_doc_auth_welcome_visited
      idv_exit_optional_questions
      idv_front_image_added
      idv_front_image_clicked
      idv_gpo_confirm_start_over_before_letter_visited
      idv_gpo_confirm_start_over_visited
      idv_gpo_expired
      idv_gpo_reminder_email_sent
      idv_image_capture_failed
      idv_in_person_email_reminder_job_email_initiated
      idv_in_person_email_reminder_job_exception
      idv_in_person_location_submitted
      idv_in_person_location_visited
      idv_in_person_locations_request_failure
      idv_in_person_locations_searched
      idv_in_person_prepare_submitted
      idv_in_person_prepare_visited
      idv_in_person_proofing_address_visited
      idv_in_person_proofing_cancel_update_state_id
      idv_in_person_proofing_enrollments_ready_for_status_check_job_completed
      idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error
      idv_in_person_proofing_enrollments_ready_for_status_check_job_started
      idv_in_person_proofing_nontransliterable_characters_submitted
      idv_in_person_proofing_redo_state_id_submitted
      idv_in_person_proofing_residential_address_submitted
      idv_in_person_proofing_state_id_submitted
      idv_in_person_proofing_state_id_visited
      idv_in_person_ready_to_verify_sp_link_clicked
      idv_in_person_ready_to_verify_what_to_bring_link_clicked
      idv_in_person_send_proofing_notification_attempted
      idv_in_person_send_proofing_notification_job_completed
      idv_in_person_send_proofing_notification_job_exception
      idv_in_person_send_proofing_notification_job_skipped
      idv_in_person_send_proofing_notification_job_started
      idv_in_person_switch_back_submitted
      idv_in_person_switch_back_visited
      idv_in_person_usps_proofing_enrollment_code_email_received
      idv_in_person_usps_proofing_results_job_completed
      idv_in_person_usps_proofing_results_job_deadline_passed_email_exception
      idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated
      idv_in_person_usps_proofing_results_job_email_initiated
      idv_in_person_usps_proofing_results_job_enrollment_incomplete
      idv_in_person_usps_proofing_results_job_enrollment_updated
      idv_in_person_usps_proofing_results_job_exception
      idv_in_person_usps_proofing_results_job_please_call_email_initiated
      idv_in_person_usps_proofing_results_job_started
      idv_in_person_usps_proofing_results_job_unexpected_response
      idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review
      idv_in_person_usps_request_enroll_exception
      idv_intro_visit
      idv_ipp_deactivated_for_never_visiting_post_office
      idv_link_sent_capture_doc_polling_complete
      idv_link_sent_capture_doc_polling_started
      idv_mail_only_warning_visited
      idv_mobile_device_and_camera_check
      idv_native_camera_forced
      idv_not_verified_visited
      idv_phone_use_different
      idv_request_letter_visited
      idv_sdk_selfie_image_capture_closed_without_photo
      idv_sdk_selfie_image_capture_failed
      idv_sdk_selfie_image_capture_opened
      idv_selfie_image_added
      idv_session_error_visited
      idv_usps_auth_token_refresh_job_completed
      idv_usps_auth_token_refresh_job_network_error
      idv_usps_auth_token_refresh_job_started
      idv_verify_by_mail_enter_code_submitted
      idv_verify_by_mail_enter_code_visited
      idv_verify_in_person_troubleshooting_option_clicked
      idv_warning_action_triggered
      idv_warning_shown
    ].to_set.freeze

    def self.included(_mod)
      raise 'this mixin is intended to be prepended, not included'
    end

    def self.prepended(mod)
      mod.instance_methods.each do |method_name|
        if should_enhance_method?(method_name)
          mod.define_method method_name do |**kwargs|
            super(**kwargs, **common_analytics_attributes)
          end
        end
      end
    end

    def self.should_enhance_method?(method_name)
      return false if IGNORED_METHODS.include?(method_name)

      method_name.start_with?('idv_')
    end

    private

    def common_analytics_attributes
      {
        proofing_components: proofing_components,
        active_profile_idv_level: active_profile&.idv_level,
        pending_profile_idv_level: pending_profile&.idv_level,
        profile_history: profile_history,
      }.compact
    end

    def active_profile
      return if !user&.respond_to?(:active_profile) || !user.active_profile
      user.active_profile
    end

    def pending_profile
      return if !user&.respond_to?(:pending_profile) || !user.pending_profile
      user.pending_profile
    end

    def profile_history
      return if !user&.respond_to?(:profiles)

      (user&.profiles || []).
        sort_by { |profile| profile.created_at }.
        map { |profile| ProfileLogging.new(profile) }.
        presence
    end

    def proofing_components
      return if !user&.respond_to?(:proofing_component) || !user.proofing_component
      ProofingComponentsLogging.new(user.proofing_component)
    end
  end
end
