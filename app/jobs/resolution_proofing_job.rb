class ResolutionProofingJob < ApplicationJob
  queue_as :default

  def perform(args)
    result_id = args[:result_id]
    Idv::Proofer.resolution_job_class.handle(
      event: {
        applicant_pii: args[:applicant_pii],
        callback_url: args[:callback_url],
        should_proof_state_id: args[:should_proof_state_id],
        dob_year_only: args[:dob_year_only],
        trace_id: args[:trace_id],
      },
      context: nil,
    ) do |result|
      document_capture_session = DocumentCaptureSession.new(result_id: result_id)
      document_capture_session.store_proofing_result(result[:resolution_result])
    end
  end
end
