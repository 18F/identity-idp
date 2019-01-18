module Idv
  class PhoneController < ApplicationController
    include IdvStepConcern
    include IdvFailureConcern

    attr_reader :idv_form

    before_action :confirm_step_needed
    before_action :confirm_step_allowed, except: [:failure]
    before_action :set_idv_form, except: [:failure]

    def new
      analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
    end

    def create
      result = idv_form.submit(step_params)
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_FORM, result.to_h)
      return render(:new) unless result.success?
      submit_proofing_attempt
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

    def submit_proofing_attempt
      idv_result = step.submit(step_params.to_h)
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_VENDOR, idv_result.to_h)
      redirect_to_next_step and return if idv_result.success?
      handle_proofing_failure
    end

    def handle_proofing_failure
      idv_session.previous_phone_step_params = step_params.to_h
      redirect_to failure_url(step.failure_reason)
    end

    def step_name
      :phone
    end

    def step
      @_step ||= Idv::PhoneStep.new(idv_session: idv_session)
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
      )
    end

    def failure_url(reason)
      idv_phone_failure_url(reason)
    end
  end
end
