module Verify
  class FinanceController < StepController
    before_action :confirm_step_needed

    helper_method :idv_finance_form

    def new
      analytics.track_event(Analytics::IDV_FINANCE_CCN_VISIT)
    end

    def create
      if step.complete
        redirect_to verify_phone_url
      else
        render_form
      end
    end

    private

    def step
      @_step ||= Idv::FinancialsStep.new(
        idv_form: idv_finance_form,
        idv_session: idv_session,
        analytics: analytics,
        params: step_params
      )
    end

    def step_params
      params.require(:idv_finance_form).permit(:finance_type, *Idv::FinanceForm::FINANCE_TYPES)
    end

    def confirm_step_needed
      redirect_to verify_phone_path if idv_session.financials_confirmation.try(:success?)
    end

    def render_form
      if step_params[:finance_type] == 'ccn'
        render :new
      else
        render 'verify/finance_other/new'
      end
    end

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
