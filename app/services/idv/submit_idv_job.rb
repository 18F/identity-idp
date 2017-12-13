module Idv
  class SubmitIdvJob
    def initialize(idv_session:, vendor_params:)
      @idv_session = idv_session
      @vendor_params = vendor_params
    end

    def submit_profile_job
      update_idv_session
      ProfileJob.perform_later(proofer_job_params)
    end

    def submit_phone_job
      update_idv_session
      PhoneJob.perform_later(proofer_job_params)
    end

    private

    attr_reader :idv_session, :vendor_params

    def proofer_job_params
      {
        result_id: result_id,
        vendor_params: vendor_params,
        vendor_session_id: idv_session.vendor_session_id,
        applicant_json: idv_session.applicant.to_json,
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
