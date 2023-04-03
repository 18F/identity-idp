require 'rails_helper'

RSpec.describe IrsAttemptsEventsBatchJob, type: :job do
  describe '#perform' do
    context 'IRS attempts API is enabled' do
      let(:start_time) { Time.new(2020, 1, 1, 12, 0, 0, 'UTC') }
      let(:previous_hour_log_file) do
        {
          filename: 'prev_filename',
          iv: 'mock_encoded_iv',
          encrypted_key: 'mock_encoded_encrypted_key',
          requested_time:
            IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(start_time - 1.hour),

        }
      end
      let(:events) do
        [
          {
            event_key: 'key1',
            jwe: 'some_event_data_encrypted_with_jwe',
            timestamp: start_time + 10.minutes,
          },
          {
            event_key: 'key2',
            jwe: 'some_other_event_data_encrypted_with_jwe',
            timestamp: start_time + 15.minutes,
          },
        ]
      end
      let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
      let(:encoded_public_key) { Base64.strict_encode64(private_key.public_key.to_der) }
      let(:expected_encrypted_events) do
        {
          data: events.pluck(:jwe).join("\r\n"),
          timestamp: start_time,
          public_key_str: encoded_public_key,
        }
      end

      let(:bucket_name) { 'test-bucket-name' }
      let(:envelope_encryptor_result) do
        IrsAttemptsApi::EnvelopeEncryptor::Result.new(
          filename: 'test-filename',
          iv: 'test-iv',
          encrypted_key: 'test-encrypted-key',
          encrypted_data: 'test-encrypted-data',
        )
      end
      let(:expected_s3_call) do
        {
          bucket_name: bucket_name,
          filename: envelope_encryptor_result[:filename],
          encrypted_data: envelope_encryptor_result[:encrypted_data],

        }
      end
      let(:expected_batch_results) do
        { filename: envelope_encryptor_result[:filename],
          iv: Base64.strict_encode64(envelope_encryptor_result[:iv]),
          encrypted_key: Base64.strict_encode64(envelope_encryptor_result[:encrypted_key]),
          requested_time: IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(start_time) }
      end

      let(:logger_info_attributes) do
        {
          name: 'IRSAttemptsEventJob',
          start_time: Time.zone.now,
          end_time: Time.zone.now,
          duration_ms: 0.1234,
          events_count: 2,
          file_bytes_size: 19,

        }
      end

      let!(:s3_put_object_response) { double(etag: true) }
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(true)

        allow_any_instance_of(described_class).to receive(:reasonable_timespan?).and_return(true)

        allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
          and_return(encoded_public_key)

        allow(IrsAttemptsApi::EnvelopeEncryptor).to receive(:encrypt).
          and_return(envelope_encryptor_result)

        allow_any_instance_of(described_class).to receive(
          :create_and_upload_to_attempts_s3_resource,
        ).and_return(s3_put_object_response)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return(bucket_name)

        allow_any_instance_of(described_class).to receive(:duration_ms).and_return(0.1234)

        travel_to start_time + 1.hour

        redis_client = IrsAttemptsApi::RedisClient.new
        events.each do |event|
          redis_client.write_event(**event)
        end
      end

      context 'When there are no missing previous files' do
        before do
          IrsAttemptApiLogFile.create(**previous_hour_log_file)
        end

        it 'batches/writes attempt events, and does not call BatchJob on previous hour' do
          expect(described_class).not_to receive(:perform_later)

          expect(IrsAttemptsApi::EnvelopeEncryptor).to receive(:encrypt).with(
            **expected_encrypted_events,
          )

          expect_any_instance_of(described_class).to receive(
            :create_and_upload_to_attempts_s3_resource,
          ).with(
            **expected_s3_call,
          )

          expect_any_instance_of(described_class).to receive(:logger_info_hash).with(
            **logger_info_attributes,
          )

          result = IrsAttemptsEventsBatchJob.perform_now(start_time)

          expect(result).not_to be_nil
          expect(result).to have_attributes(expected_batch_results)
        end

        context 'When irs delete_events feature flag and s3 put_object response are true' do
          before do
            allow(IdentityConfig.store).to receive(:irs_attempt_api_delete_events_after_s3_upload).
              and_return(true)
          end

          it 'delete the events from redis' do
            IrsAttemptsEventsBatchJob.perform_now
            events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: start_time)
            expect(events.count).to eq 0
          end
        end

        context 'When irs delete_events feature flag is false' do
          before do
            allow(IdentityConfig.store).to receive(:irs_attempt_api_delete_events_after_s3_upload).
              and_return(false)
          end

          it 'does not delete the events from redis' do
            IrsAttemptsEventsBatchJob.perform_now
            events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: start_time)
            expect(events.count).to eq 2
          end
        end

        context 'When irs delete_events feature flag is true and s3 put_object response is false' do
          let!(:s3_put_object_response) { double(etag: false) }
          before do
            allow(IdentityConfig.store).to receive(:irs_attempt_api_delete_events_after_s3_upload).
              and_return(true)
          end

          it 'does not delete the events from redis' do
            IrsAttemptsEventsBatchJob.perform_now
            events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: start_time)
            expect(events.count).to eq 2
          end
        end
      end

      context 'When there are missing previous files' do
        it 'batches/writes expected attempt events and calls BatchJob on previous hour' do
          expect(described_class).to receive(:perform_later).with(
            start_time - 1.hour,
          )

          expect(IrsAttemptsApi::EnvelopeEncryptor).to receive(:encrypt).with(
            **expected_encrypted_events,
          )

          expect_any_instance_of(described_class).to receive(
            :create_and_upload_to_attempts_s3_resource,
          ).with(
            **expected_s3_call,
          )

          expect_any_instance_of(described_class).to receive(:logger_info_hash).with(
            **logger_info_attributes,
          )

          result = IrsAttemptsEventsBatchJob.perform_now(start_time)

          expect(result).not_to be_nil
          expect(result).to have_attributes(expected_batch_results)
        end
      end
    end

    context 'IRS attempts API is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)
      end

      it 'returns nil' do
        result = IrsAttemptsEventsBatchJob.perform_now
        expect(result).to eq(nil)
      end
    end

    context 'IRS attempts bucket name is not set' do
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).and_return(false)
      end

      it 'returns nil' do
        result = IrsAttemptsEventsBatchJob.perform_now
        expect(result).to eq(nil)
      end
    end
  end

  describe '#reasonable_timespan?' do
    it 'returns true for yesterday' do
      result = IrsAttemptsEventsBatchJob.new.reasonable_timespan?(Time.zone.now - 1.day)
      expect(result).to eq(true)
    end
    it 'returns false for a week ago' do
      result = IrsAttemptsEventsBatchJob.new.reasonable_timespan?(Time.zone.now - 7.days)
      expect(result).to eq(false)
    end
  end
end
