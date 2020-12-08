class DocumentCaptureSession < ApplicationRecord
  include NonNullUuid

  belongs_to :user

  def load_result
    EncryptedRedisStructStorage.load(result_id, type: DocumentCaptureSessionResult)
  end

  def store_result_from_response(doc_auth_response)
    EncryptedRedisStructStorage.store(
      DocumentCaptureSessionResult.new(
        id: generate_result_id,
        success: doc_auth_response.success?,
        pii: doc_auth_response.pii_from_doc,
      ),
      expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
    )
    save!
  end

  def load_doc_auth_async_result
    EncryptedRedisStructStorage.load(result_id, type: DocumentCaptureSessionAsyncResult)
  end

  def create_doc_auth_session
    EncryptedRedisStructStorage.store(
      DocumentCaptureSessionAsyncResult.new(
        id: generate_result_id,
        status: DocumentCaptureSessionAsyncResult::IN_PROGRESS,
      ),
      expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
    )
    save!
  end

  def store_doc_auth_result(result:, pii:)
    EncryptedRedisStructStorage.store(
      DocumentCaptureSessionAsyncResult.new(
        id: result_id,
        pii: pii,
        result: result,
        status: DocumentCaptureSessionAsyncResult::DONE,
      ),
      expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
    )
    save!
  end

  def load_proofing_result
    EncryptedRedisStructStorage.load(result_id, type: ProofingDocumentCaptureSessionResult)
  end

  def create_proofing_session
    EncryptedRedisStructStorage.store(
      ProofingDocumentCaptureSessionResult.new(
        id: generate_result_id,
        status: ProofingDocumentCaptureSessionResult::IN_PROGRESS,
        result: nil,
      ),
      expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
    )
    save!
  end

  def store_proofing_result(proofing_result)
    EncryptedRedisStructStorage.store(
      ProofingDocumentCaptureSessionResult.new(
        id: result_id,
        result: proofing_result,
        status: ProofingDocumentCaptureSessionResult::DONE,
      ),
      expires_in: AppConfig.env.async_wait_timeout_seconds.to_i,
    )
  end

  def expired?
    return true unless requested_at
    requested_at + AppConfig.env.doc_capture_request_valid_for_minutes.to_i.minutes < Time.zone.now
  end

  private

  def generate_result_id
    self.result_id = SecureRandom.uuid
  end
end
