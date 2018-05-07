module Idv
  class ProoferJob < ApplicationJob
    queue_as :idv

    attr_reader :result_id, :applicant, :stages

    def perform(result_id:, applicant_json:, stages:)
      @result_id = result_id
      @applicant = from_json(applicant_json)
      @stages = from_json(stages).map(&:to_sym)
      verify_identity_with_vendor
    end

    private

    def from_json(applicant_json)
      JSON.parse(applicant_json, symbolize_names: true)
    end

    def verify_identity_with_vendor
      agent = Idv::Agent.new(applicant)
      result = agent.proof(*stages)
      store_result(Idv::VendorResult.new(result.to_h))
    rescue StandardError => error
      store_failed_job_result(error)
      raise
    end

    def store_failed_job_result(error)
      job_failed_result = Idv::VendorResult.new(
        errors: { job_failed: true, message: error.message }
      )
      VendorValidatorResultStorage.new.store(result_id: result_id, result: job_failed_result)
    end

    def store_result(vendor_result)
      VendorValidatorResultStorage.new.store(result_id: result_id, result: vendor_result)
    end
  end
end
