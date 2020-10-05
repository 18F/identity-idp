class VendorProofJob
  def self.perform_resolution_proof(document_capture_session_id, proof_state_id)
    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_id)
    result = dcs.load_proofing_result
    idv_result = Idv::Agent.new(result.pii).proof_resolution(should_proof_state_id: proof_state_id)
    dcs.store_proofing_result(idv_result)
  end

  def self.perform_address_proof(document_capture_session_id)
    dcs = DocumentCaptureSession.find_by(uuid: document_capture_session_id)
    result = dcs.load_proofing_result
    idv_result = Idv::Agent.new(result.pii).proof_address
    dcs.store_proofing_result(idv_result)
  end
end
