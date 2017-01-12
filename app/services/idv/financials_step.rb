module Idv
  class FinancialsStep < Step
    def complete?
      idv_form.finance_type && idv_session.financials_confirmation.try(:success?) ? true : false
    end

    private

    def vendor_validate
      result = vendor_validator.validate
      idv_session.params = idv_form.idv_params if complete?
      result
    end

    def vendor_validator_class
      Idv::FinancialsValidator
    end

    def analytics_event
      Analytics::IDV_FINANCE_CONFIRMATION
    end

    def vendor_errors
      idv_session.financials_confirmation.try(:errors)
    end

    def vendor_params
      finance_type = idv_form.finance_type
      { finance_type => idv_form.idv_params[finance_type] }
    end
  end
end
