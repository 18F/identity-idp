require 'rails_helper'

RSpec.describe IdentityJobLogSubscriber, type: :job do
  subject(:subscriber) { IdentityJobLogSubscriber.new }

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
    encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
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

    expect do
      AddressProofingJob.perform_later(
        result_id: nil,
        encrypted_arguments: 'abc',
        trace_id: nil,
        user_id: SecureRandom.random_number(1000),
        issuer: build(:service_provider).issuer,
      )
    end.to raise_error(ArgumentError)
  end

  describe '#enqueue_retry' do
    it 'formats retry message' do
      event = double(
        'RetryEvent',
        payload: { wait: 1, job: double('Job', job_id: '1', queue_name: 'Default', arguments: []) },
        duration: 1,
        name: 'TestEvent',
      )

      hash = subscriber.enqueue_retry(event)
      expect(hash[:wait_ms]).to eq 1000
      expect(hash[:duration_ms]).to eq 1
    end

    it 'includes exception if there is a failure' do
      job = double('Job', job_id: '1', queue_name: 'Default', arguments: [])
      allow(job.class).to receive(:warning_error_classes).and_return([])

      event = double(
        'RetryEvent',
        payload: {
          wait: 1,
          job: job,
          error: double('Exception'),
        },
        duration: 1,
        name: 'TestEvent',
      )

      hash = subscriber.enqueue_retry(event)
      expect(hash[:exception_class]).to_not be_nil
    end
  end

  describe '#enqueue' do
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

    it 'logs warnings when exception occurs in job with warning error classes' do
      job = RiscDeliveryJob.new

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: Errno::ECONNREFUSED.new,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:warn) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          exception_class_warn: 'Errno::ECONNREFUSED',
          exception_message_warn: 'Connection refused',
          job_class: 'RiscDeliveryJob',
          job_id: job.job_id,
          name: 'enqueue.active_job',
          queue_name: kind_of(String),
          timestamp: kind_of(String),
          trace_id: nil,
        )
      end

      subscriber.enqueue(event)
    end

    it 'halts' do
      job = RiscDeliveryJob.new

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: nil,
        aborted: true,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:info) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          halted: true,
          job_class: 'RiscDeliveryJob',
          job_id: job.job_id,
          name: 'enqueue.active_job',
          queue_name: 'NilClass(low)',
          timestamp: kind_of(String),
          trace_id: nil,
        )
      end

      subscriber.enqueue(event)
    end

    it 'processes as normal' do
      job = RiscDeliveryJob.new
      job.scheduled_at = Time.zone.now

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: nil,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:info) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          timestamp: kind_of(String),
          name: 'enqueue.active_job',
          job_class: 'RiscDeliveryJob',
          trace_id: nil,
          queue_name: 'NilClass(low)',
          job_id: job.job_id,
        )
      end

      subscriber.enqueue(event)
    end
  end

  describe '#enqueue_at' do
    let(:event_uuid) { SecureRandom.uuid }
    let(:now) { Time.zone.now }
    let(:job) { HeartbeatJob.new }

    it 'does report the duplicate key error as an exception' do
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

      expect(subscriber).to receive(:error) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to have_key(:exception_class)
        expect(payload).to have_key(:exception_message)
      end

      subscriber.enqueue_at(event)
    end

    it 'logs warnings when exception occurs in job with warning error classes' do
      job = RiscDeliveryJob.new

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: Errno::ECONNREFUSED.new,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:warn) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          exception_class_warn: 'Errno::ECONNREFUSED',
          exception_message_warn: 'Connection refused',
          job_class: 'RiscDeliveryJob',
          job_id: job.job_id,
          name: 'enqueue.active_job',
          queue_name: kind_of(String),
          timestamp: kind_of(String),
          trace_id: nil,
        )
      end

      subscriber.enqueue_at(event)
    end

    it 'is compatible with job classes that do not inherit from ApplicationJob' do
      # rubocop:disable Rails/ApplicationJob
      class SampleJob < ActiveJob::Base; def perform(_); end; end
      # rubocop:enable Rails/ApplicationJob

      job = SampleJob.new

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: Errno::ECONNREFUSED.new,
      )

      subscriber.enqueue_at(event)
    end

    it 'halts' do
      job = RiscDeliveryJob.new

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: nil,
        aborted: true,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:info) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          halted: true,
          job_class: 'RiscDeliveryJob',
          job_id: job.job_id,
          name: 'enqueue.active_job',
          queue_name: 'NilClass(low)',
          timestamp: kind_of(String),
          trace_id: nil,
        )
      end

      subscriber.enqueue_at(event)
    end

    it 'processes as normal' do
      job = RiscDeliveryJob.new
      job.scheduled_at = Time.zone.now

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        exception_object: nil,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:info) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          timestamp: kind_of(String),
          name: 'enqueue.active_job',
          job_class: 'RiscDeliveryJob',
          trace_id: nil,
          queue_name: 'NilClass(low)',
          job_id: job.job_id,
          scheduled_at: kind_of(String),
        )
      end

      subscriber.enqueue_at(event)
    end
  end

  describe '#discard' do
    let(:event_uuid) { SecureRandom.uuid }
    let(:now) { Time.zone.now }
    let(:job) { HeartbeatJob.new }

    it 'logs warnings when exception occurs in job with warning error classes' do
      job = RiscDeliveryJob.new
      job.scheduled_at = Time.zone.now

      event = ActiveSupport::Notifications::Event.new(
        'enqueue.active_job',
        now,
        now,
        event_uuid,
        job: job,
        error: Errno::ECONNREFUSED.new,
      )

      expect(subscriber).to_not receive(:error)
      expect(subscriber).to receive(:warn) do |str|
        payload = JSON.parse(str, symbolize_names: true)

        expect(payload).to_not have_key(:exception_class)
        expect(payload).to_not have_key(:exception_message)

        expect(payload).to match(
          duration_ms: kind_of(Float),
          timestamp: kind_of(String),
          name: 'enqueue.active_job',
          job_class: 'RiscDeliveryJob',
          trace_id: nil,
          queue_name: kind_of(String),
          job_id: job.job_id,
          exception_class_warn: 'Errno::ECONNREFUSED',
        )
      end

      subscriber.discard(event)
    end
  end
end
