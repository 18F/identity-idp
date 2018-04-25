module Idv
  class SubmitIdvJob
    def initialize(idv_session:, vendor_params:, stages:)
      @idv_session = idv_session
      @vendor_params = vendor_params
      @stages = stages
    end

    def submit
      update_idv_session
      ProoferJob.perform_later(proofer_job_params)
    end

    private

    attr_reader :idv_session, :vendor_params, :stages

    def proofer_job_params
      {
        result_id: result_id,
        applicant_json: idv_session.applicant.merge(vendor_params).to_json,
        stages: stages.to_json,
      }
    end

    def result_id
      @_result_id ||= SecureRandom.uuid
    end

    def update_idv_session
      idv_session.async_result_id = result_id
      idv_session.async_result_started_at = Time.zone.now.to_i
    end
  end
end
