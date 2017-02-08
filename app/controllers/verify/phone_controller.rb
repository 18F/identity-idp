module Verify
  class PhoneController < ApplicationController
    include IdvStepConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed

    helper_method :idv_phone_form

    def new
      analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION, result.to_h)
      increment_step_attempts

      if result.success?
        redirect_to verify_review_url
      elsif step_attempts_exceeded?
        redirect_to_fail_path
      else
        process_failure
      end
    end

    private

    def step_name
      :phone
    end

    def step
      @_step ||= Idv::PhoneStep.new(
        idv_form: idv_phone_form,
        idv_session: idv_session,
        params: step_params
      )
    end

    def process_failure
      show_warning if step.form_valid_but_vendor_validation_failed?
      render :new
    end

    def show_warning
      presenter = VerificationWarningPresenter.new(step_name, remaining_step_attempts)

      flash.now[:warning] = presenter.warning_message
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone)
    end

    def confirm_step_needed
      redirect_to verify_review_path if idv_session.phone_confirmation == true
    end

    def idv_phone_form
      @_idv_phone_form ||= Idv::PhoneForm.new(idv_session.params, current_user)
    end
  end
end
