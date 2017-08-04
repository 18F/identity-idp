module Idv
  class FinancialsStep < Step
    def submit
      if complete?
        @success = true
        idv_session.financials_confirmation = true
        idv_session.params = idv_form_params
      else
        @success = false
        idv_session.financials_confirmation = false
      end

      FormResponse.new(success: success, errors: errors)
    end

    private

    attr_reader :success

    def complete?
      vendor_validation_passed?
    end
  end
end
