module Idv
  module AnalyticsEventsEnhancer
    DECORATED_METHODS = %i[
      idv_cancellation_confirmed
      idv_cancellation_go_back
      idv_cancellation_visited
      idv_come_back_later_visit
      idv_forgot_password
      idv_forgot_password_confirmed
      idv_final
      idv_gpo_address_letter_enqueued
      idv_gpo_address_letter_requested
      idv_in_person_ready_to_verify_visit
      idv_personal_key_acknowledgment_toggled
      idv_personal_key_downloaded
      idv_personal_key_submitted
      idv_personal_key_visited
      idv_phone_confirmation_form_submitted
      idv_phone_confirmation_otp_rate_limit_attempts
      idv_phone_confirmation_otp_rate_limit_locked_out
      idv_phone_confirmation_otp_rate_limit_sends
      idv_phone_confirmation_otp_resent
      idv_phone_confirmation_otp_sent
      idv_phone_confirmation_otp_submitted
      idv_phone_confirmation_otp_visit
      idv_phone_confirmation_vendor_submitted
      idv_phone_error_visited
      idv_phone_of_record_visited
      idv_phone_otp_delivery_selection_visit
      idv_phone_otp_delivery_selection_submitted
      idv_proofing_resolution_result_missing
      idv_review_complete
      idv_review_info_visited
      idv_setup_errors_visited
      idv_start_over
    ].freeze

    DECORATED_METHODS.each do |method_name|
      define_method(method_name) do |**kwargs|
        super(**kwargs, **common_analytics_attributes)
      end
    end

    def self.included(_mod)
      raise 'this mixin is intended to be prepended, not included'
    end

    private

    def common_analytics_attributes
      {
        proofing_components: proofing_components,
      }
    end

    def proofing_components
      return if !user&.respond_to?(:proofing_component) || !user.proofing_component
      ProofingComponentsLogging.new(user.proofing_component)
    end
  end
end
