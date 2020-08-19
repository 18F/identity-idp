class DocumentCaptureSession < ApplicationRecord
  include NonNullUuid

  belongs_to :user

  def load_result
    DocumentCaptureSessionResult.load(result_id)
  end

  def store_result_from_response(doc_auth_response)
    DocumentCaptureSessionResult.store(
      id: generate_result_id,
      success: doc_auth_response.success?,
      pii: doc_auth_response.pii_from_doc,
    )
  end

  private

  def generate_result_id
    self.result_id = SecureRandom.uuid
  end
end
