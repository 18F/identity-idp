module Verify
  class PhoneController < StepController
    before_action :confirm_step_needed

    helper_method :idv_phone_form

    def new
      analytics.track_event(Analytics::IDV_PHONE_RECORD_VISIT)
    end

    def create
      result = step.submit
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION, result.to_h)

      if result.success?
        redirect_to verify_review_url
      else
        render :new
      end
    end

    private

    def step
      @_step ||= Idv::PhoneStep.new(
        idv_form: idv_phone_form,
        idv_session: idv_session,
        analytics: analytics,
        params: step_params
      )
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
