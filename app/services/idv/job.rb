module Idv
  module Job
    class << self
      def submit(idv_session, stages)
        result_id = SecureRandom.uuid

        idv_session.async_result_id = result_id
        idv_session.async_result_started_at = Time.zone.now.to_i

        Idv::ProoferJob.perform_later(
          result_id: result_id,
          applicant_json: idv_session.vendor_params.to_json,
          stages: stages.to_json
        )
      end
    end
  end
end
