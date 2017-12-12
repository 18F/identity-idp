module Idv
  class ProoferJob < ApplicationJob
    queue_as :idv

    attr_reader :result_id, :applicant, :vendor_params, :vendor_session_id

    def perform(result_id:, vendor_params:, applicant_json:, vendor_session_id: nil)
      @result_id = result_id
      @vendor_params = vendor_params
      @applicant = applicant_from_json(applicant_json)
      @vendor_session_id = vendor_session_id
      perform_identity_proofing
    end

    def verify_identity_with_vendor
      raise NotImplementedError, "subclass must implement #{__method__}"
    end

    private

    def agent
      Idv::Agent.new(applicant: applicant, vendor: vendor)
    end

    def applicant_from_json(applicant_json)
      applicant_attributes = JSON.parse(applicant_json, symbolize_names: true)
      Proofer::Applicant.new(applicant_attributes)
    end

    def perform_identity_proofing
      verify_identity_with_vendor
    rescue StandardError
      store_failed_job_result
      raise
    end

    def extract_result(confirmation)
      vendor_resp = confirmation.vendor_resp

      Idv::VendorResult.new(
        success: confirmation.success?,
        errors: confirmation.errors,
        reasons: vendor_resp.reasons
      )
    end

    def store_failed_job_result
      job_failed_result = Idv::VendorResult.new(errors: { job_failed: true })
      VendorValidatorResultStorage.new.store(result_id: result_id, result: job_failed_result)
    end

    def store_result(vendor_result)
      VendorValidatorResultStorage.new.store(result_id: result_id, result: vendor_result)
    end
  end
end
