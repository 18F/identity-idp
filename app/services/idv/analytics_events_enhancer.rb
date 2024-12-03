# frozen_string_literal: true

module Idv
  # For events beginning with +idv_+, add additional information to the event
  # when a User object is available:
  # - +proofing_components+: User's current proofing components
  # - +active_profile_idv_level+: ID verification level of user's active profile.
  # - +pending_profile_idv_level+: ID verification level of user's pending profile.
  # Generally, analytics events that are called in contexts where there is no expectation
  # of an {Idv::Session} being present (e.g., jobs, client-generated events, action scripts)
  # are opted-out.
  #
  # Additionally, +profile_history+, the list of a User's profiles
  # (sorted by creaton date, oldest to newest), may be added to events, but this is opt-in only.
  # See {AnalyticsEventsEnhancer::METHODS_WITH_PROFILE_HISTORY} for the list of included events.
  module AnalyticsEventsEnhancer
    EXCLUDED_FRONTEND_EVENT_METHODS = [
      :idv_acuant_sdk_loaded,
      :idv_barcode_warning_continue_clicked,
      :idv_barcode_warning_retake_photos_clicked,
      :idv_camera_info_error,
      :idv_camera_info_logged,
      :idv_capture_troubleshooting_dismissed,
      :idv_consent_checkbox_toggled,
      :idv_image_capture_failed,
      :idv_in_person_location_submitted,
      :idv_in_person_ready_to_verify_sp_link_clicked,
      :idv_in_person_ready_to_verify_what_to_bring_link_clicked,
      :idv_link_sent_capture_doc_polling_complete,
      :idv_link_sent_capture_doc_polling_started,
      :idv_native_camera_forced,
      :idv_sdk_error_before_init,
      :idv_sdk_selfie_image_capture_closed_without_photo,
      :idv_sdk_selfie_image_capture_failed,
      :idv_sdk_selfie_image_capture_initialized,
      :idv_sdk_selfie_image_capture_opened,
      :idv_sdk_selfie_image_re_taken,
      :idv_sdk_selfie_image_taken,
      :idv_selfie_image_added,
      :idv_verify_in_person_troubleshooting_option_clicked,
      :idv_warning_action_triggered,
      :idv_warning_shown,
    ].freeze

    EXCLUDED_JOB_EVENT_METHODS = [
      :idv_gpo_expired,
      :idv_gpo_reminder_email_sent,
      :idv_in_person_email_reminder_job_email_initiated,
      :idv_in_person_email_reminder_job_exception,
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_completed,
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_ingestion_error,
      :idv_in_person_proofing_enrollments_ready_for_status_check_job_started,
      :idv_in_person_send_proofing_notification_attempted,
      :idv_in_person_send_proofing_notification_job_completed,
      :idv_in_person_send_proofing_notification_job_exception,
      :idv_in_person_send_proofing_notification_job_skipped,
      :idv_in_person_send_proofing_notification_job_started,
      :idv_in_person_usps_proofing_enrollment_code_email_received,
      :idv_in_person_usps_proofing_results_job_completed,
      :idv_in_person_usps_proofing_results_job_deadline_passed_email_exception,
      :idv_in_person_usps_proofing_results_job_deadline_passed_email_initiated,
      :idv_in_person_usps_proofing_results_job_email_initiated,
      :idv_in_person_usps_proofing_results_job_enrollment_incomplete,
      :idv_in_person_usps_proofing_results_job_enrollment_updated,
      :idv_in_person_usps_proofing_results_job_exception,
      :idv_in_person_usps_proofing_results_job_please_call_email_initiated,
      :idv_in_person_usps_proofing_results_job_started,
      :idv_in_person_usps_proofing_results_job_unexpected_response,
      :idv_in_person_usps_proofing_results_job_user_sent_to_fraud_review,
      :idv_ipp_deactivated_for_never_visiting_post_office,
      :idv_socure_document_request_submitted,
      :idv_socure_reason_code_download,
      :idv_socure_shadow_mode_proofing_result,
      :idv_socure_shadow_mode_proofing_result_missing,
      :idv_socure_verification_data_requested,
      :idv_usps_auth_token_refresh_job_completed,
      :idv_usps_auth_token_refresh_job_network_error,
      :idv_usps_auth_token_refresh_job_started,
    ].freeze

    EXCLUDED_MISC_EVENT_METHODS = [
      :idv_in_person_proofing_nontransliterable_characters_submitted,
    ].freeze

    IGNORED_METHODS = [
      *EXCLUDED_FRONTEND_EVENT_METHODS,
      *EXCLUDED_JOB_EVENT_METHODS,
      *EXCLUDED_MISC_EVENT_METHODS,
    ].uniq.freeze

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
    ].uniq.freeze

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
      AnalyticsEventsEnhancer.extra_args_for_method(method_name)
        .index_with do |arg_name|
          send(arg_name.to_s).presence
        end
        .compact
    end

    def active_profile_idv_level
      user&.respond_to?(:active_profile) && user&.active_profile&.idv_level
    end

    def pending_profile_idv_level
      user&.respond_to?(:pending_profile) && user&.pending_profile&.idv_level
    end

    def profile_history
      return if !user&.respond_to?(:profiles)

      (user&.profiles || [])
        .sort_by { |profile| profile.created_at }
        .map { |profile| ProfileLogging.new(profile) }
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
