module Idv
  class PhoneController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneOtpRateLimitable
    include PhoneOtpSendable

    attr_reader :idv_form

    before_action :confirm_not_rate_limited_for_phone_address_verification, except: [:new]
    before_action :confirm_step_allowed
    before_action :confirm_verify_info_step_complete
    before_action :set_idv_form

    def new
      flash.keep(:success) if should_keep_flash_success?
      analytics.idv_phone_use_different(step: params[:step]) if params[:step]

      async_state = step.async_state

      # It's possible that create redirected here after a success and left the
      # rate_limiter maxed out. Check for success before checking rate_limiter.
      return async_state_done(async_state) if async_state.done?

      render 'shared/wait' and return if async_state.in_progress?

      return if confirm_not_rate_limited_for_phone_address_verification

      if async_state.none?
        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
          call(:verify_phone, :view, true)

        analytics.idv_phone_of_record_visited(**ab_test_analytics_buckets)
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      elsif async_state.missing?
        analytics.proofing_address_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      end
    end

    def create
      clear_future_steps!
      result = idv_form.submit(step_params)
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:verify_phone, :update, result.success?)

      analytics.idv_phone_confirmation_form_submitted(**result.to_h, **ab_test_analytics_buckets)
      irs_attempts_api_tracker.idv_phone_submitted(
        success: result.success?,
        phone_number: step_params[:phone],
      )
      if result.success?
        submit_proofing_attempt
        redirect_to idv_phone_path
      else
        flash.now[:error] = result.first_error_message
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :phone,
        controller: self,
        action: :new,
        next_steps: [:otp_verification],
        preconditions: ->(idv_session:, user:) { idv_session.verify_info_step_complete? },
        undo_step: ->(idv_session:, user:) do
          idv_session.vendor_phone_confirmation = nil
          idv_session.address_verification_mechanism = nil
          idv_session.idv_phone_step_document_capture_session_uuid = nil
          idv_session.user_phone_confirmation_session = nil
          idv_session.previous_phone_step_params = nil # do we want to save this?
        end,
      )
    end

    private

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(user: current_user, rate_limit_type: :proof_address)
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        if OutageStatus.new.all_phone_vendor_outage?
          redirect_to vendor_outage_path(from: :idv_phone)
        else
          send_phone_confirmation_otp_and_handle_result
        end
      else
        redirect_to idv_enter_password_url
      end
    end

    def phone_confirmation_required?
      idv_session.user_phone_confirmation != true
    end

    def submit_proofing_attempt
      step.submit(step_params.to_h)
    end

    def send_phone_confirmation_otp_and_handle_result
      save_delivery_preference
      result = send_phone_confirmation_otp
      analytics.idv_phone_confirmation_otp_sent(
        **result.to_h.merge(adapter: Telephony.config.adapter),
      )

      irs_attempts_api_tracker.idv_phone_otp_sent(
        phone_number: @idv_phone,
        success: result.success?,
        otp_delivery_method: idv_session.previous_phone_step_params[:otp_delivery_preference],
      )
      if result.success?
        redirect_to idv_otp_verification_url
      else
        handle_send_phone_confirmation_otp_failure(result)
      end
    end

    def handle_send_phone_confirmation_otp_failure(result)
      if send_phone_confirmation_otp_rate_limited?
        handle_too_many_otp_sends
      else
        invalid_phone_number(result.extra[:telephony_response].error)
      end
    end

    def handle_proofing_failure
      redirect_to failure_url(step.failure_reason)
    end

    def step_name
      :phone
    end

    def step
      @step ||= Idv::PhoneStep.new(
        idv_session: idv_session,
        trace_id: amzn_trace_id,
        analytics: analytics,
        attempts_tracker: irs_attempts_api_tracker,
      )
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone, :international_code, :otp_delivery_preference)
    end

    def set_idv_form
      @idv_form = Idv::PhoneForm.new(
        user: current_user,
        previous_params: idv_session.previous_phone_step_params,
        allowed_countries:
          PhoneNumberCapabilities::ADDRESS_IDENTITY_PROOFING_SUPPORTED_COUNTRY_CODES,
        failed_phone_numbers: idv_session.failed_phone_step_numbers,
        hybrid_handoff_phone_number: idv_session.phone_for_mobile_flow,
      )
    end

    def failure_url(reason)
      case reason
      when :warning
        idv_phone_errors_warning_url
      when :timeout
        idv_phone_errors_timeout_url
      when :jobfail
        idv_phone_errors_jobfail_url
      when :fail
        idv_phone_errors_failure_url
      end
    end

    def async_state_done(async_state)
      form_result = step.async_state_done(async_state)

      analytics.idv_phone_confirmation_vendor_submitted(
        **form_result.to_h.merge(
          pii_like_keypaths: [
            [:errors, :phone],
            [:context, :stages, :address],
          ],
          new_phone_added: new_phone_added?,
          hybrid_handoff_phone_used: hybrid_handoff_phone_used?,
        ),
      )

      if form_result.success?
        redirect_to_next_step
      else
        handle_proofing_failure
      end
    end

    def is_req_from_frontend?
      request.headers['HTTP_X_FORM_STEPS_WAIT'] == '1'
    end

    def is_req_from_verify_step?
      request.referer == idv_verify_info_url
    end

    def should_keep_flash_success?
      is_req_from_frontend? && is_req_from_verify_step?
    end

    def new_phone_added?
      context = MfaContext.new(current_user)
      configured_phones = context.phone_configurations.map(&:phone).map do |number|
        PhoneFormatter.format(number)
      end
      !configured_phones.include?(formatted_previous_phone_step_params_phone)
    end

    def hybrid_handoff_phone_used?
      formatted_previous_phone_step_params_phone ==
        PhoneFormatter.format(idv_session.phone_for_mobile_flow)
    end

    def formatted_previous_phone_step_params_phone
      PhoneFormatter.format(
        idv_session.previous_phone_step_params&.fetch('phone'),
      )
    end

    def gpo_letter_available
      return @gpo_letter_available if defined?(@gpo_letter_available)
      @gpo_letter_available ||= FeatureManagement.gpo_verification_enabled? &&
                                !Idv::GpoMail.new(current_user).rate_limited?
    end

    # Migrated from otp_delivery_method_controller
    def otp_sent_tracker_error(result)
      if send_phone_confirmation_otp_rate_limited?
        { rate_limited: true }
      else
        { telephony_error: result.extra[:telephony_response]&.error&.friendly_message }
      end
    end

    # Migrated from otp_delivery_method_controller
    def save_delivery_preference
      original_session = idv_session.user_phone_confirmation_session
      idv_session.user_phone_confirmation_session = Idv::PhoneConfirmationSession.new(
        code: original_session.code,
        phone: original_session.phone,
        sent_at: original_session.sent_at,
        delivery_method: original_session.delivery_method,
      )
    end
  end
end
