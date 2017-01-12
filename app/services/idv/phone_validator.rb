module Idv
  class PhoneValidator < VendorValidator
    def validate
      session_id = idv_session.resolution.session_id
      idv_session.phone_confirmation = idv_agent.submit_phone(vendor_params, session_id)
      idv_session.phone_confirmation.success?
    end
  end
end
