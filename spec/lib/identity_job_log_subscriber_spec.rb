require 'rails_helper'

RSpec.describe IdentityJobLogSubscriber, type: :job do
  it 'logs events' do
    expect(Rails.logger).to receive(:info).at_least(3).times do |log|
      return if log.nil?
      json = JSON.parse(log)
      expect(json['name']).to be_in [
        'enqueue.active_job', 'perform_start.active_job', 'perform.active_job'
      ]
      expect(json['job_class']).to eq('AddressProofingJob')
      expect(json.key?('trace_id'))
      expect(json.key?('duration_ms'))
      expect(json.key?('job_id'))
      expect(json.key?('timestamp'))
    end

    document_capture_session = DocumentCaptureSession.new(result_id: SecureRandom.hex)
    encrypted_arguments = Encryption::Encryptors::SessionEncryptor.new.encrypt(
      { applicant_pii: { phone: Faker::PhoneNumber.cell_phone } }.to_json,
    )

    AddressProofingJob.perform_later(
      result_id: document_capture_session.result_id,
      encrypted_arguments: encrypted_arguments, callback_url: nil, trace_id: nil
    )
  end
end
