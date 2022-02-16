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

  it 'logs no errors when exception occurs in job and job is set to warn_only' do
    allow(RiscDeliveryJob).to receive(:perform).with(any_args).and_raise(Faraday::SSLError)

    expect(Rails.logger).to receive(:error).exactly(0).times

    expect {
      RiscDeliveryJob.new.perform(
        issuer: build(:service_provider).issuer,
        push_notification_url: 'url',
        jwt: 'jwt',
        event_type: 'event_type',
      )
    }.to_not raise_error(Faraday::SSLError)
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

  describe '#enqueue' do
    subject(:subscriber) { IdentityJobLogSubscriber.new }

    let(:event_uuid) { SecureRandom.uuid }
    let(:now) { Time.zone.now }
    let(:job) { HeartbeatJob.new }

    it 'does not report the duplicate key error as an exception' do
      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: ActiveRecord::RecordNotUnique.new(<<~ERR),
          PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "index_good_jobs_on_cron_key_and_cron_at"
          DETAIL: Key (cron_key, cron_at)=(heartbeat_job, 2022-01-28 17:35:00) already exists.
        ERR
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:warn) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Numeric),
          exception_class_warn: 'ActiveRecord::RecordNotUnique',
          exception_message_warn: /(cron_key, cron_at)/,
          job_class: 'HeartbeatJob',
          job_id: job.job_id,
          name: 'enqueue.active_job',
          queue_name: kind_of(String),
          timestamp: kind_of(String),
          trace_id: nil,
        )
      end

      subscriber.enqueue(event)
    end
  end
end
