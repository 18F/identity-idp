module Idv
  class FinancialsStep < Step
    def call
      if complete?
        @success = true
        idv_session.financials_confirmation = true
        idv_session.params = idv_form.idv_params
      else
        @success = false
        idv_session.financials_confirmation = false
      end

      result
    end

    private

    def complete?
      form_valid? && vendor_valid?
    end

    def vendor_validator_class
      Idv::FinancialsValidator
    end

    def vendor_errors
      vendor_validator.errors
    end

    def vendor_params
      finance_type = idv_form.finance_type
      { finance_type => idv_form.idv_params[finance_type] }
    end
  end
end
