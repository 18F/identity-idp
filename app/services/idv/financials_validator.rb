module Idv
  class FinancialsValidator < VendorValidator
    def validate
      session_id = idv_session.resolution.session_id
      idv_session.financials_confirmation = idv_agent.submit_financials(vendor_params, session_id)
      idv_session.financials_confirmation.success?
    end
  end
end
