require 'rails_helper'

RSpec.describe AddressProofingJob, type: :job do
  it 'stores results' do
    document_capture_session = DocumentCaptureSession.new(result_id: SecureRandom.hex)
    encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { applicant_pii: { phone: Faker::PhoneNumber.cell_phone } }.to_json,
    )

    AddressProofingJob.perform_now(
      result_id: document_capture_session.result_id,
      encrypted_arguments: encrypted_arguments, callback_url: nil, trace_id: nil
    )

    result = document_capture_session.load_proofing_result[:result]
    expect(result).to be_present
  end
end
