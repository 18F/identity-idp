require 'rails_helper'

RSpec.describe DocumentProofingJob, type: :job do
  let(:front_image_url) { 'http://example.com/front' }
  let(:back_image_url) { 'http://example.com/back' }
  let(:encryption_key) { SecureRandom.random_bytes(32) }
  let(:front_image_iv) { SecureRandom.random_bytes(12) }
  let(:back_image_iv) { SecureRandom.random_bytes(12) }

  before do
    body = '{}'
    encrypt_and_stub_s3(body: body, url: front_image_url, iv: front_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: back_image_url, iv: back_image_iv, key: encryption_key)
  end

  it 'stores results' do
    document_arguments = {
      encryption_key: Base64.encode64(encryption_key),
      front_image_iv: Base64.encode64(front_image_iv),
      back_image_iv: Base64.encode64(back_image_iv),
      front_image_url: front_image_url,
      back_image_url: back_image_url,
    }

    document_capture_session = DocumentCaptureSession.new(result_id: SecureRandom.hex)
    encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { document_arguments: document_arguments }.to_json,
    )

    DocumentProofingJob.perform_later(
      result_id: document_capture_session.result_id,
      liveness_checking_enabled: false, encrypted_arguments: encrypted_arguments,
      trace_id: nil
    )

    result = document_capture_session.load_doc_auth_async_result
    expect(result).to be_present
  end
end
