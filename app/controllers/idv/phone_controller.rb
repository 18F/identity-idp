module Idv
  class PhoneController < ApplicationController
    include IdvStepConcern

    attr_reader :idv_form

    before_action :confirm_step_needed
    before_action :set_idv_form

    def new
      analytics.idv_phone_use_different(step: params[:step]) if params[:step]

      redirect_to failure_url(:fail) and return if throttle.throttled?

      async_state = step.async_state
      if async_state.none?
        analytics.idv_phone_of_record_visited
        render_new_with_locals
      elsif async_state.in_progress?
        render :wait
      elsif async_state.missing?
        analytics.proofing_address_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render_new_with_locals
      elsif async_state.done?
        async_state_done(async_state)
      end
    end

    def create
      result = idv_form.submit(step_params)
      analytics.idv_phone_confirmation_form_submitted(**result.to_h)
      flash[:error] = result.first_error_message if !result.success?
      return render_new_with_locals if !result.success?
      submit_proofing_attempt
      redirect_to idv_phone_path
    end

    private

    def render_new_with_locals
      render :new,
             locals: {
               step_indicator_steps: step_indicator_steps,
               gpo_letter_available: gpo_letter_available,
             }
    end

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
        else
          redirect_to idv_otp_delivery_method_url
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
      params.require(:idv_phone_form).permit(:phone)
    end

    def confirm_step_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def set_idv_form
      @idv_form = Idv::PhoneForm.new(
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
                                !Idv::GpoMail.new(current_user).mail_spammed? &&
                                !(sp_session[:ial2_strict] &&
                                  !IdentityConfig.store.gpo_allowed_for_strict_ial2)
    end
  end
end
