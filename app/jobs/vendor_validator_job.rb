class VendorValidatorJob < ActiveJob::Base
  queue_as :idv

  def perform(result_id:, vendor_validator_class:, vendor:, vendor_params:, applicant_json:,
              vendor_session_id:)
    vendor_validator = vendor_validator_class.constantize.new(
      applicant: Proofer::Applicant.new(JSON.parse(applicant_json, symbolize_names: true)),
      vendor: vendor,
      vendor_params: indifferent_access(vendor_params),
      vendor_session_id: vendor_session_id
    )

    VendorValidatorResultStorage.new.store(
      result_id: result_id,
      result: extract_result(vendor_validator.result)
    )
  end

  private

  def extract_result(result)
    vendor_resp = result.vendor_resp

    Idv::VendorResult.new(
      success: result.success?,
      errors: result.errors,
      reasons: vendor_resp.reasons,
      normalized_applicant: vendor_resp.try(:normalized_applicant),
      session_id: result.try(:session_id)
    )
  end

  def indifferent_access(params)
    return params if params.is_a?(String)
    params.with_indifferent_access
  end
end
