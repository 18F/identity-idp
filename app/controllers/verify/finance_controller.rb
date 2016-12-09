module Verify
  class FinanceController < StepController
    helper_method :idv_finance_form

    def new
      analytics.track_event(Analytics::IDV_FINANCE_VISIT)
    end

    def create
      if idv_finance_form.submit(finance_params)
        idv_session.params = idv_finance_form.idv_params
        redirect_to verify_phone_url
      else
        render :new
      end
    end

    private

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end

    def finance_params
      params.require(:idv_finance_form).permit(:finance_type, *Idv::FinanceForm::FINANCE_TYPES)
    end
  end
end
