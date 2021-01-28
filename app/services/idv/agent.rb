module Idv
  class Agent
    def initialize(applicant)
      @applicant = applicant.symbolize_keys
    end

    def proof_resolution(document_capture_session, should_proof_state_id:, trace_id:)
      callback_url = Rails.application.routes.url_helpers.resolution_proof_result_url(
        document_capture_session.result_id,
      )

      LambdaJobs::Runner.new(
        job_class: Idv::Proofer.resolution_job_class,
        args: {
          applicant_pii: @applicant,
          callback_url: callback_url,
          should_proof_state_id: should_proof_state_id,
          dob_year_only: AppConfig.env.proofing_send_partial_dob == 'true',
          trace_id: trace_id,
        },
      ).run do |idv_result|
        document_capture_session.store_proofing_result(idv_result[:resolution_result])

        nil
      end
    end

    def proof_address(document_capture_session, trace_id:)
      callback_url = Rails.application.routes.url_helpers.address_proof_result_url(
        document_capture_session.result_id,
      )

      LambdaJobs::Runner.new(
        job_class: Idv::Proofer.address_job_class,
        args: { applicant_pii: @applicant, callback_url: callback_url, trace_id: trace_id },
      ).run do |idv_result|
        document_capture_session.store_proofing_result(idv_result[:address_result])

        nil
      end
    end

    private

    def init_results
      {
        errors: {},
        messages: [],
        context: {
          stages: [],
        },
        exception: nil,
        success: false,
        timed_out: false,
      }
    end
  end
end
