require 'rails_helper'

RSpec.describe DocumentProofingJob, type: :job do
  it 'stores results' do
    encryption_helper = IdentityIdpFunctions::EncryptionHelper.new
    encryption_key = SecureRandom.random_bytes(32)
    front_image_iv = SecureRandom.random_bytes(12)
    back_image_iv = SecureRandom.random_bytes(12)


    stub_request(:get, 'http://example.com/front').
      to_return(body: encryption_helper.encrypt(
        data: '{}', key: encryption_key, iv: front_image_iv,
    ))
    stub_request(:get, 'http://example.com/back').
      to_return(body: encryption_helper.encrypt(
        data: '{}', key: encryption_key, iv: back_image_iv,
    ))
    document_arguments = {
      encryption_key: Base64.encode64(encryption_key),
      front_image_iv: Base64.encode64(front_image_iv),
      back_image_iv: Base64.encode64(back_image_iv),
      front_image_url: 'http://example.com/front',
      back_image_url: 'http://example.com/back',
    }

    document_capture_session = DocumentCaptureSession.new(result_id: SecureRandom.hex)
    encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { document_arguments: document_arguments }.to_json,
    )

    DocumentProofingJob.perform_now(
      result_id: document_capture_session.result_id,
      liveness_checking_enabled: false, encrypted_arguments: encrypted_arguments,
      callback_url: nil, trace_id: nil
    )

    result = document_capture_session.load_doc_auth_async_result
    expect(result).to be_present
  end
end
