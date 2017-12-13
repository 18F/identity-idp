module Idv
  class ProfileJob < ProoferJob
    attr_accessor :resolution, :confirmation

    def verify_identity_with_vendor
      self.resolution = resolution_agent.start(vendor_params_hash)

      return build_and_store_result unless resolution.success?

      self.confirmation = confirmation_agent.submit_state_id(state_id_vendor_params)
      build_and_store_result
    end

    private

    def confirmation_agent
      Idv::Agent.new(
        vendor: Figaro.env.state_id_proofing_vendor.to_sym,
        applicant: applicant
      )
    end

    def resolution_agent
      Idv::Agent.new(
        vendor: Figaro.env.profile_proofing_vendor.to_sym,
        applicant: applicant
      )
    end

    def result_errors
      resolution_errors = resolution.errors
      confirmation_errors = confirmation&.errors || {}
      resolution_errors.merge(confirmation_errors)
    end

    def result_reasons
      resolution_reasons = resolution.vendor_resp.reasons
      confirmation_reasons = confirmation&.vendor_resp&.reasons || []
      resolution_reasons + confirmation_reasons
    end

    def result_successful?
      return confirmation.success? if confirmation.present?
      resolution.success?
    end

    def state_id_vendor_params
      vendor_params_hash.merge(state_id_jurisdiction: vendor_params_hash[:state])
    end

    def build_and_store_result
      resolution_vendor_resp = resolution.vendor_resp
      result = Idv::VendorResult.new(
        success: result_successful?,
        errors: result_errors,
        reasons: result_reasons,
        normalized_applicant: resolution_vendor_resp.normalized_applicant,
        session_id: resolution.session_id
      )
      store_result(result)
    end

    def vendor_params_hash
      vendor_params.with_indifferent_access
    end
  end
end
