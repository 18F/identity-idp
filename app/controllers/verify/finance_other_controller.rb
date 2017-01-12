module Verify
  class FinanceOtherController < StepController
    before_action :confirm_step_needed

    helper_method :idv_finance_form

    def new
      analytics.track_event(Analytics::IDV_FINANCE_OTHER_VISIT)
    end

    private

    def confirm_step_needed
      redirect_to verify_phone_path if idv_session.financials_confirmation.try(:success?)
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
