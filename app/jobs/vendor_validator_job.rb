class VendorValidatorJob < ApplicationJob
  queue_as :idv

  def perform(result_id:, vendor_validator_class:, vendor:, vendor_params:, applicant_json:,
              vendor_session_id:)
    vendor_validator = vendor_validator_class.constantize.new(
      applicant: Proofer::Applicant.new(JSON.parse(applicant_json, symbolize_names: true)),
      vendor: vendor.to_sym,
      vendor_params: indifferent_access(vendor_params),
      vendor_session_id: vendor_session_id
    )

    extract_result_and_store_if_job_passed(result_id, vendor_validator)
  rescue StandardError
    store_failed_job_result(result_id)
    raise
  end

  private

  def extract_result_and_store_if_job_passed(result_id, validator)
    validator_result = extract_result(validator.result)

    VendorValidatorResultStorage.new.store(result_id: result_id, result: validator_result)
  end

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

  def store_failed_job_result(result_id)
    job_failed_result = Idv::VendorResult.new(errors: { job_failed: true })

    VendorValidatorResultStorage.new.store(result_id: result_id, result: job_failed_result)
  end

  def indifferent_access(params)
    return params if params.is_a?(String)
    params.with_indifferent_access
  end
end
