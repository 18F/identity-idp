module Idv
  class ProoferJob < ApplicationJob
    queue_as :idv

    attr_reader :result_id, :applicant, :vendor_params, :stages

    def perform(result_id:, vendor_params:, applicant_json:, stages:)
      @result_id = result_id
      @vendor_params = vendor_params
      @applicant = applicant_from_json(applicant_json)
      @stages = stages
      perform_proofing
    end

    private

    def applicant_from_json(applicant_json)
      JSON.parse(applicant_json, symbolize_names: true)
    end

    def perform_proofing
      agent = Idv::Agent.new(applicant)
      result = agent.proof(vendor_params, *stages)
      store_result(Idv::VendorResult.new(result))
    rescue StandardError
      store_failed_job_result
      raise
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
