class DocumentCaptureSession < ApplicationRecord
  include NonNullUuid

  belongs_to :user

  def load_result
    EncryptedRedisStructStorage.load(result_id, type: DocumentCaptureSessionResult)
  end

  def load_proofing_result
    EncryptedRedisStructStorage.load(result_id, type: ProofingDocumentCaptureSessionResult)
  end

  def store_result_from_response(doc_auth_response)
    EncryptedRedisStructStorage.store(
      DocumentCaptureSessionResult.new(
        id: generate_result_id,
        success: doc_auth_response.success?,
        pii: doc_auth_response.pii_from_doc,
      ),
    )
    save!
  end

  def store_proofing_pii_from_doc(pii_from_doc)
    EncryptedRedisStructStorage.store(
      ProofingDocumentCaptureSessionResult.new(
        id: generate_result_id,
        pii: pii_from_doc,
        result: nil,
      ),
    )
    save!
  end

  def store_proofing_result(pii_from_doc, result)
    EncryptedRedisStructStorage.store(
      ProofingDocumentCaptureSessionResult.new(
        id: result_id,
        pii: pii_from_doc,
        result: result,
      ),
    )
  end

  def expired?
    return true unless requested_at
    requested_at + Figaro.env.doc_capture_request_valid_for_minutes.to_i.minutes < Time.zone.now
  end

  private

  def generate_result_id
    self.result_id = SecureRandom.uuid
  end
end
