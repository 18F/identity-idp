module Verify
  class PhoneController < ApplicationController
    include IdvStepConcern
    include IdvFailureConcern

    before_action :confirm_step_needed
    before_action :confirm_step_allowed
    before_action :submit_idv_form, only: [:create]
    before_action :submit_idv_job, only: [:create]

    def new
      @view_model = view_model
      analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result.to_h)
      increment_step_attempts

      if result.success?
        redirect_to verify_review_url
      else
        render_failure
        render :new
      end
    end

    private

    def submit_idv_form
      result = idv_form.submit(step_params)
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_FORM, result.to_h)

      return if result.success?

      @view_model = view_model
      render :new
    end

    def submit_idv_job
      SubmitIdvJob.new(
        vendor_validator_class: Idv::PhoneValidator,
        idv_session: idv_session,
        vendor_params: idv_session.params[:phone]
      ).call
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

    def view_model(error: nil)
      Verify::PhoneNew.new(
        error: error,
        remaining_attempts: remaining_step_attempts,
        idv_form: idv_form
      )
    end

    def step_params
      params.require(:idv_phone_form).permit(:phone)
    end

    def confirm_step_needed
      redirect_to verify_review_path if idv_session.phone_confirmation == true
    end

    def idv_form
      @_idv_form ||= Idv::PhoneForm.new(idv_session.params, current_user)
    end
  end
end
