module Idv
  class FinancialsStep < Step
    def submit
      if complete?
        @success = true
        idv_session.financials_confirmation = true
        idv_session.params = idv_form.idv_params
      else
        @success = false
        idv_session.financials_confirmation = false
      end

      FormResponse.new(success: success, errors: errors)
    end

    def form_valid_but_vendor_validation_failed?
      form_valid? && !vendor_validation_passed?
    end

    private

    attr_reader :success

    def complete?
      form_valid? && vendor_validation_passed?
    end

    def vendor_validator_class
      Idv::FinancialsValidator
    end

    def vendor_reasons
      vendor_validator_result.reasons if form_valid?
    end

    def vendor_params
      finance_type = idv_form.finance_type
      { finance_type => idv_form.idv_params[finance_type] }
    end
  end
end
