module Verify
  class FinancialsNew < Verify::Base
    def initialize(error: nil, remaining_attempts:, idv_finance_form:)
      @error = error
      @remaining_attempts = remaining_attempts
      @idv_finance_form = idv_finance_form
    end

    attr_reader :idv_finance_form

    def step_name
      :financials
    end
  end
end
