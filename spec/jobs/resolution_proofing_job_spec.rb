require 'rails_helper'

RSpec.describe ResolutionProofingJob, type: :job do
  it 'stores results' do
    pii = {
      ssn: '444-55-8888',
      first_name: Faker::Name.first_name,
      zipcode: Faker::Address.zip_code,
      state_id_number: '123456789',
      state_id_type: 'drivers_license',
      state_id_jurisdiction: Faker::Address.state_abbr,
    }

    document_capture_session = DocumentCaptureSession.new(result_id: SecureRandom.hex)
    encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { applicant_pii: pii }.to_json,

    )

    ResolutionProofingJob.perform_later(
      result_id: document_capture_session.result_id, should_proof_state_id: false,
      dob_year_only: false, encrypted_arguments: encrypted_arguments,
      callback_url: nil, trace_id: nil
    )

    result = document_capture_session.load_proofing_result[:result]
    expect(result).to be_present
  end
end
