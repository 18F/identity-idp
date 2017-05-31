module Idv
  class FinancialsValidator < VendorValidator
    private

    def session_id
      idv_session.vendor_session_id
    end

    def try_submit
      try_agent_action do
        idv_agent.submit_financials(vendor_params, session_id)
      end
    end
  end
end
