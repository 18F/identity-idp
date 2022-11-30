module Idv
  class PhoneController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneOtpRateLimitable
    include PhoneOtpSendable

    attr_reader :idv_form

    before_action :confirm_step_needed
    before_action :set_idv_form

    def new
      analytics.idv_phone_use_different(step: params[:step]) if params[:step]

      redirect_to failure_url(:fail) and return if throttle.throttled?

      async_state = step.async_state
      if async_state.none?
        analytics.idv_phone_of_record_visited
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      elsif async_state.in_progress?
        render :wait
      elsif async_state.missing?
        analytics.proofing_address_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      elsif async_state.done?
        async_state_done(async_state)
      end
    end

    def create
      result = idv_form.submit(step_params)
      analytics.idv_phone_confirmation_form_submitted(**result.to_h)
      irs_attempts_api_tracker.idv_phone_submitted(
        success: result.success?,
        phone_number: step_params[:phone],
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )
      flash[:error] = result.first_error_message if !result.success?
      return render :new, locals: { gpo_letter_available: gpo_letter_available } if !result.success?
      submit_proofing_attempt
      redirect_to idv_phone_path
    end

    private

    def throttle
      @throttle ||= Throttle.new(user: current_user, throttle_type: :proof_address)
    end

    def max_attempts_reached
      analytics.throttler_rate_limit_triggered(
        throttle_type: :proof_address,
        step_name: step_name,
      )
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        if VendorStatus.new.all_phone_vendor_outage?
          redirect_to vendor_outage_path(from: :idv_phone)
        elsif step.otp_delivery_preference_missing?
          redirect_to idv_otp_delivery_method_url
        else
          send_phone_confirmation_otp_and_handle_result
        end
      else
        redirect_to idv_review_url
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
        failure_reason: result.success? ? {} : otp_sent_tracker_error(result),
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
      max_attempts_reached if step.failure_reason == :fail
      redirect_to failure_url(step.failure_reason)
    end

    def step_name
      :phone
    end

    def step
      @step ||= Idv::PhoneStep.new(idv_session: idv_session, trace_id: amzn_trace_id)
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone, :otp_delivery_preference)
    end

    def confirm_step_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def set_idv_form
      @idv_form = Idv::PhoneForm.new(
        user: current_user,
        previous_params: idv_session.previous_phone_step_params,
        allowed_countries:
          PhoneNumberCapabilities::ADDRESS_IDENTITY_PROOFING_SUPPORTED_COUNTRY_CODES,
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
        ),
      )
      redirect_to_next_step and return if async_state.result[:success]
      handle_proofing_failure
    end

    def new_phone_added?
      context = MfaContext.new(current_user)
      configured_phones = context.phone_configurations.map(&:phone).map do |number|
        PhoneFormatter.format(number)
      end
      applicant_phone = PhoneFormatter.format(idv_session.applicant['phone'])
      !configured_phones.include?(applicant_phone)
    end

    def gpo_letter_available
      return @gpo_letter_available if defined?(@gpo_letter_available)
      @gpo_letter_available ||= FeatureManagement.enable_gpo_verification? &&
                                !Idv::GpoMail.new(current_user).mail_spammed?
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
      idv_session.user_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.new(
        code: original_session.code,
        phone: original_session.phone,
        sent_at: original_session.sent_at,
        delivery_method: original_session.delivery_method,
      )
    end
  end
end
