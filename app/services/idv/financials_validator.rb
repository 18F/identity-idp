module Idv
  class FinancialsValidator < VendorValidator
    private

    def try_submit
      try_agent_action do
        idv_agent.submit_financials(vendor_params, vendor_session_id)
      end
    end
  end
end
