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
        attention_with_barcode: doc_auth_response.attention_with_barcode?,
      ),
      expires_in: IdentityConfig.store.doc_capture_request_valid_for_minutes.minutes.seconds.to_i,
    )
    self.ocr_confirmation_pending = doc_auth_response.attention_with_barcode?
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
      expires_in: IdentityConfig.store.async_wait_timeout_seconds,
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
      expires_in: IdentityConfig.store.async_wait_timeout_seconds,
    )
    self.ocr_confirmation_pending = result[:attention_with_barcode]
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

  private

  def generate_result_id
    self.result_id = SecureRandom.uuid
  end
end

# == Schema Information
#
# Table name: document_capture_sessions
#
#  id                       :bigint           not null, primary key
#  cancelled_at             :datetime
#  ial2_strict              :boolean
#  issuer                   :string
#  ocr_confirmation_pending :boolean          default(FALSE)
#  requested_at             :datetime
#  uuid                     :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  result_id                :string
#  user_id                  :bigint
#
# Indexes
#
#  index_document_capture_sessions_on_result_id  (result_id)
#  index_document_capture_sessions_on_user_id    (user_id)
#  index_document_capture_sessions_on_uuid       (uuid)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
