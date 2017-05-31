module Idv
  class PhoneValidator < VendorValidator
    private

    def session_id
      idv_session.vendor_session_id
    end

    def try_submit
      try_agent_action do
        idv_agent.submit_phone(vendor_params, session_id)
      end
    end
  end
end
