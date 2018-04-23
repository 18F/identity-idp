module Idv
  class PhoneJob < ProoferJob
    def verify_identity_with_vendor
      confirmation = agent.submit_phone(vendor_params)
      result = extract_result(confirmation)
      store_result(result)
    end

    private

    def vendor
      Figaro.env.phone_proofing_vendor.to_sym
    end
  end
end
