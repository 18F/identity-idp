class VendorProofJob < ApplicationJob
  queue_as :default

  def perform(document_capture_session_id, stages)
    binding.pry
    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_id)
    result = dcs.load_proofing_result
    idv_result = Idv::Agent.new(result.pii).proof(*stages)
    dcs.store_proofing_result(idv_result)
  end
end
