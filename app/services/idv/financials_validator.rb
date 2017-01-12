module Idv
  class FinancialsValidator < VendorValidator
    def success?
      result.success?
    end

    def errors
      result.errors
    end

    private

    def result
      @_result ||= idv_agent.submit_financials(vendor_params, session_id)
    end

    def session_id
      idv_session.resolution.session_id
    end
  end
end
