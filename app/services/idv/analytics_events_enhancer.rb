# frozen_string_literal: true

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
      idv_doc_auth_redo_ssn_submitted
      idv_doc_auth_socure_webhook_received
      idv_doc_auth_ssn_submitted
      idv_doc_auth_ssn_visited
      idv_doc_auth_submitted_image_upload_form
      idv_doc_auth_submitted_image_upload_vendor
      idv_socure_verification_data_requested
      idv_doc_auth_submitted_pii_validation
      idv_doc_auth_verify_proofing_results
      idv_doc_auth_verify_submitted
      idv_doc_auth_verify_visited
      idv_doc_auth_warning_visited
      idv_doc_auth_welcome_submitted
      idv_doc_auth_welcome_visited
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
      idv_in_person_proofing_enrollments_ready_for_status_check_job_completed
      idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error
      idv_in_person_proofing_enrollments_ready_for_status_check_job_started
      idv_in_person_proofing_nontransliterable_characters_submitted
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
      idv_ipp_deactivated_for_never_visiting_post_office
      idv_link_sent_capture_doc_polling_complete
      idv_link_sent_capture_doc_polling_started
      idv_mail_only_warning_visited
      idv_native_camera_forced
      idv_not_verified_visited
      idv_phone_use_different
      idv_request_letter_visited
      idv_sdk_selfie_image_capture_closed_without_photo
      idv_sdk_selfie_image_capture_failed
      idv_sdk_selfie_image_capture_opened
      idv_selfie_image_added
      idv_session_error_visited
      idv_threatmetrix_response_body
      idv_usps_auth_token_refresh_job_completed
      idv_usps_auth_token_refresh_job_network_error
      idv_usps_auth_token_refresh_job_started
      idv_verify_by_mail_enter_code_submitted
      idv_verify_by_mail_enter_code_visited
      idv_verify_in_person_troubleshooting_option_clicked
      idv_warning_action_triggered
      idv_warning_shown
    ].to_set.freeze

    STANDARD_ARGUMENTS = %i[
      proofing_components
      active_profile_idv_level
      pending_profile_idv_level
    ].freeze

    METHODS_WITH_PROFILE_HISTORY = %i[
      idv_doc_auth_verify_proofing_results
      idv_intro_visit
      idv_final
      idv_please_call_visited
      idv_start_over
    ].to_set.freeze

    def self.included(_mod)
      raise 'this mixin is intended to be prepended, not included'
    end

    def self.prepended(mod)
      mod.instance_methods.each do |method_name|
        if should_enhance_method?(method_name)
          mod.define_method method_name do |**kwargs|
            super(**kwargs, **analytics_attributes(method_name))
          end
        end
      end
    end

    def self.should_enhance_method?(method_name)
      return false if IGNORED_METHODS.include?(method_name)
      method_name.start_with?('idv_')
    end

    def self.extra_args_for_method(method_name)
      return [] unless should_enhance_method?(method_name)

      args = STANDARD_ARGUMENTS

      if METHODS_WITH_PROFILE_HISTORY.include?(method_name)
        args = [
          *args,
          :profile_history,
        ]
      end

      args
    end

    private

    def analytics_attributes(method_name)
      AnalyticsEventsEnhancer.extra_args_for_method(method_name).
        index_with do |arg_name|
          send(arg_name.to_s).presence
        end.
        compact
    end

    def active_profile_idv_level
      user&.respond_to?(:active_profile) && user&.active_profile&.idv_level
    end

    def pending_profile_idv_level
      user&.respond_to?(:pending_profile) && user&.pending_profile&.idv_level
    end

    def profile_history
      return if !user&.respond_to?(:profiles)

      (user&.profiles || []).
        sort_by { |profile| profile.created_at }.
        map { |profile| ProfileLogging.new(profile) }
    end

    def proofing_components
      return if !user

      user_session = session&.dig('warden.user.user.session') || {}

      idv_session = Idv::Session.new(
        user_session:,
        current_user: user,
        service_provider: sp,
      )

      proofing_components_hash = ProofingComponents.new(
        idv_session:,
        session:,
        user:,
        user_session:,
      ).to_h

      proofing_components_hash.empty? ? nil : proofing_components_hash
    end
  end
end
