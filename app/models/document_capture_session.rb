class DocumentCaptureSession < ApplicationRecord
  include NonNullUuid

  belongs_to :user

  def load_result
    return nil unless result_id.present?
    EncryptedRedisStructStorage.load(result_id, type: DocumentCaptureSessionResult)
  end

  def store_result_from_response(doc_auth_response)
    session_result = load_result || DocumentCaptureSessionResult.new(
      id: generate_result_id,
    )
    session_result.success = doc_auth_response.success?
    session_result.pii = doc_auth_response.pii_from_doc
    session_result.captured_at = Time.zone.now
    session_result.attention_with_barcode = doc_auth_response.attention_with_barcode?
    session_result.selfie_check_performed = doc_auth_response.selfie_check_performed?
    EncryptedRedisStructStorage.store(
      session_result,
      expires_in: IdentityConfig.store.doc_capture_request_valid_for_minutes.minutes.seconds.to_i,
    )
    self.ocr_confirmation_pending = doc_auth_response.attention_with_barcode?
    save!
  end

  def store_failed_auth_image_fingerprint(front_image_fingerprint, back_image_fingerprint)
    session_result = load_result || DocumentCaptureSessionResult.new(
      id: generate_result_id,
    )
    session_result.success = false
    session_result.captured_at = Time.zone.now
    session_result.add_failed_front_image!(front_image_fingerprint) if front_image_fingerprint
    session_result.add_failed_back_image!(back_image_fingerprint) if back_image_fingerprint
    EncryptedRedisStructStorage.store(
      session_result,
      expires_in: IdentityConfig.store.doc_capture_request_valid_for_minutes.minutes.seconds.to_i,
    )
    save!
  end

  def load_proofing_result
    EncryptedRedisStructStorage.load(result_id, type: ProofingSessionAsyncResult)
  end

  def create_proofing_session
    EncryptedRedisStructStorage.store(
      ProofingSessionAsyncResult.new(
        id: generate_result_id,
        status: ProofingSessionAsyncResult::IN_PROGRESS,
        result: nil,
      ),
      expires_in: IdentityConfig.store.async_wait_timeout_seconds,
    )
    save!
  end

  def store_proofing_result(proofing_result)
    EncryptedRedisStructStorage.store(
      ProofingSessionAsyncResult.new(
        id: result_id,
        result: proofing_result,
        status: ProofingSessionAsyncResult::DONE,
      ),
      expires_in: IdentityConfig.store.async_wait_timeout_seconds,
    )
  end

  def expired?
    return true unless requested_at
    (requested_at + IdentityConfig.store.doc_capture_request_valid_for_minutes.minutes) <
      Time.zone.now
  end

  def confirm_ocr
    return unless self.ocr_confirmation_pending

    update!(ocr_confirmation_pending: false)
  end

  private

  def generate_result_id
    self.result_id = SecureRandom.uuid
  end
end
