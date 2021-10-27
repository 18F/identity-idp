module Idv
  class PhoneController < ApplicationController
    include IdvStepConcern

    attr_reader :idv_form

    before_action :confirm_step_needed
    before_action :set_idv_form

    def new
      redirect_to failure_url(:fail) and return if idv_attempter_throttled?

      async_state = step.async_state
      if async_state.none?
        analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      elsif async_state.in_progress?
        render :wait
      elsif async_state.timed_out?
        analytics.track_event(Analytics::PROOFING_ADDRESS_TIMEOUT)
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :new, locals: { gpo_letter_available: gpo_letter_available }
      elsif async_state.done?
        async_state_done(async_state)
      end
    end

    def create
      result = idv_form.submit(step_params)
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_FORM, result.to_h)
      return render :new, locals: { gpo_letter_available: gpo_letter_available } if !result.success?
      submit_proofing_attempt
      redirect_to idv_phone_path
    end

    private

    def max_attempts_reached
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_resolution,
        step_name: step_name,
      )
    end

    def redirect_to_next_step
      if phone_confirmation_required?
        redirect_to idv_otp_delivery_method_url
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

    def handle_proofing_failure
      max_attempts_reached if step.failure_reason == :fail
      redirect_to failure_url(step.failure_reason)
    end

    def step_name
      :phone
    end

    def step
      @_step ||= Idv::PhoneStep.new(idv_session: idv_session, trace_id: amzn_trace_id)
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone)
    end

    def confirm_step_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def set_idv_form
      @idv_form ||= Idv::PhoneForm.new(
        user: current_user,
        previous_params: idv_session.previous_phone_step_params,
        allowed_countries: ['US'],
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
      analytics.track_event(
        Analytics::IDV_PHONE_CONFIRMATION_VENDOR,
        form_result.to_h.merge(
          pii_like_keypaths: [
            [:errors, :phone],
            [:context, :stages, :address],
          ],
        ),
      )
      redirect_to_next_step and return if async_state.result[:success]
      handle_proofing_failure
    end

    def gpo_letter_available
      @_gpo_letter_available ||= FeatureManagement.enable_gpo_verification? &&
                                 !Idv::GpoMail.new(current_user).mail_spammed?
    end
  end
end
