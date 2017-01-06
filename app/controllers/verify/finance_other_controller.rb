module Verify
  class FinanceOtherController < StepController
    helper_method :idv_finance_form

    def new
      analytics.track_event(Analytics::IDV_FINANCE_OTHER_VISIT)
    end

    private

    def idv_finance_form
      @_idv_finance_form ||= Idv::FinanceForm.new(idv_session.params)
    end
  end
end
