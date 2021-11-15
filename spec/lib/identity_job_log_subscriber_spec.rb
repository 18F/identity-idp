require 'rails_helper'

RSpec.describe IdentityJobLogSubscriber, type: :job do
  it 'logs events' do
    expect(Rails.logger).to receive(:info).at_least(3).times do |log|
      next if log.nil?
      json = log.is_a?(Hash) ? log : JSON.parse(log)
      next if json['name'].nil?
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
      encrypted_arguments: encrypted_arguments,
      trace_id: nil,
      user_id: SecureRandom.random_number(1000),
      issuer: build(:service_provider).issuer,
    )
  end

  it 'logs errors when exception occurs in job' do
    expect(Rails.logger).to receive(:error).exactly(2).times do |log|
      json = JSON.parse(log)

      expect(json['name']).to be_in [
        'enqueue.active_job', 'perform.active_job'
      ]
      expect(json['job_class']).to eq('AddressProofingJob')
      expect(json.key?('trace_id'))
      expect(json.key?('duration_ms'))
      expect(json.key?('job_id'))
      expect(json.key?('timestamp'))
      expect(json['exception_class']).to eq('ArgumentError')
      expect(json['exception_message']).to eq 'invalid base64'
    end

    expect {
      AddressProofingJob.perform_later(
        result_id: nil,
        encrypted_arguments: 'abc',
        trace_id: nil,
        user_id: SecureRandom.random_number(1000),
        issuer: build(:service_provider).issuer,
      )
    }.to raise_error(ArgumentError)
  end

  describe '#enqueue_retry' do
    it 'formats retry message' do
      event = double(
        'RetryEvent',
        payload: { wait: 1, job: double('Job', job_id: '1', queue_name: 'Default', arguments: []) },
        duration: 1,
        name: 'TestEvent',
      )
      subscriber = IdentityJobLogSubscriber.new
      hash = subscriber.enqueue_retry(event)
      expect(hash[:wait_ms]).to eq 1000
      expect(hash[:duration_ms]).to eq 1
    end

    it 'includes exception if there is a failure' do
      event = double(
        'RetryEvent',
        payload: {
          wait: 1, job: double(
            'Job', job_id: '1', queue_name: 'Default', arguments: []
          ),
          error: double('Exception')
        },
        duration: 1,
        name: 'TestEvent',
      )
      subscriber = IdentityJobLogSubscriber.new
      hash = subscriber.enqueue_retry(event)
      expect(hash[:exception_class]).to_not be_nil
    end
  end
end
