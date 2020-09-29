class VendorProofJob
  def self.perform(document_capture_session_id, stages)
    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_id)
    result = dcs.load_proofing_result
    stages = stages.map(&:to_sym)
    idv_result = Idv::Agent.new(result.pii).proof(*stages)
    dcs.store_proofing_result(result.pii, idv_result)

    # something like....
    LambdaJobs::Runner.execute(job_name: 'proofer-job', args: result.pii)
  end
end
