module Idv
  class PhoneController < ApplicationController
    include IdvStepConcern
    include IdvFailureConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed, except: [:failure]
    before_action :refresh_if_not_ready, only: [:show]

    def new
      @idv_form = idv_form
      analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
    end

    def create
      @idv_form = idv_form
      result = @idv_form.submit(step_params)
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_FORM, result.to_h)

      if result.success?
        Idv::Job.submit(idv_session, [:address])
        redirect_to idv_phone_result_url
      else
        render :new
      end
    end

    def show
      result = step.submit
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result.to_h)
      increment_step_attempts

      redirect_to_next_step and return if result.success?
      redirect_to idv_phone_failure_url(idv_step_failure_reason)
    end

    def failure
      render_idv_step_failure(:phone, params[:reason].to_sym)
    end

    private

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

    def step_name
      :phone
    end

    def step
      @_step ||= Idv::PhoneStep.new(
        idv_session: idv_session,
        idv_form_params: idv_form.idv_params,
        vendor_validator_result: vendor_validator_result
      )
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone)
    end

    def confirm_step_needed
      redirect_to_next_step if idv_session.user_phone_confirmation == true
    end

    def idv_form
      @_idv_form ||= Idv::PhoneForm.new(idv_session.params, current_user)
    end

    def failure_url(reason)
      idv_phone_failure_url(reason)
    end
  end
end
