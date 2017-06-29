module Idv
  class PhoneValidator < VendorValidator
    private

    def try_submit
      try_agent_action do
        idv_agent.submit_phone(vendor_params, vendor_session_id)
      end
    end
  end
end
