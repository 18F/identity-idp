module Idv
  class ProfileJob < ProoferJob
    def verify_identity_with_vendor
      resolution = agent.start(vendor_params)
      result = extract_result(resolution)
      store_result(result)
    end

    private

    def extract_result(resolution)
      vendor_resp = resolution.vendor_resp

      Idv::VendorResult.new(
        success: resolution.success?,
        errors: resolution.errors,
        reasons: vendor_resp.reasons,
        normalized_applicant: vendor_resp.normalized_applicant,
        session_id: resolution.session_id
      )
    end
  end
end
