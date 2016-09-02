module Idv
  class FinanceController < StepController
    helper_method :idv_finance_form

    def new
    end

    def create
      if idv_finance_form.submit(finance_params)
        self.idv_params = idv_finance_form.idv_params
        redirect_to idv_phone_url
      else
        render :new
      end
    end

    private

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_params)
    end

    def finance_params
      params.require(:idv_finance_form).permit(:finance_type, :finance_account)
    end
  end
end
