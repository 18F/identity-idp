require 'rails_helper'

RSpec.describe IrsAttemptsEventsBatchJob, type: :job do
  describe '#perform' do
    context 'IRS attempts API is enabled' do
      let(:start_time) { Time.new(2020, 1, 1, 12, 0, 0, 'UTC') }
      let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
      # let(:public_key) { private_key.public_key }
      let(:encoded_public_key) { Base64.strict_encode64(private_key.public_key.to_der) }
      let(:bucket_name) { 'test-bucket-name' }
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

      let(:envelope_encryptor_result) do
        IrsAttemptsApi::EnvelopeEncryptor::Result.new(
          filename: 'test-filename',
          iv: 'test-iv',
          encrypted_key: 'test-encrypted-key',
          encrypted_data: 'test-encrypted-data',
        )
      end

      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
          and_return(encoded_public_key)

        allow(IdentityConfig.store).to receive(:irs_attempt_api_bucket_name).
          and_return(bucket_name)

        allow(IrsAttemptsApi::EnvelopeEncryptor).to receive(:encrypt).
          and_return(envelope_encryptor_result)

        allow_any_instance_of(described_class).to receive(
          :create_and_upload_to_attempts_s3_resource,
        )

        travel_to start_time + 1.hour

        redis_client = IrsAttemptsApi::RedisClient.new
        events.each do |event|
          redis_client.write_event(
            event_key: event[:event_key],
            jwe: event[:jwe],
            timestamp: event[:timestamp],
          )
        end
      end

      it 'batches and writes attempt events to an encrypted file' do
        expect(IrsAttemptsApi::EnvelopeEncryptor).to receive(:encrypt).with(
          data: events.pluck(:jwe).join("\r\n"),
          timestamp: start_time,
          public_key_str: encoded_public_key,
        )

        expect_any_instance_of(described_class).to receive(
          :create_and_upload_to_attempts_s3_resource,
        ).with(
          bucket_name: 'test-bucket-name',
          filename: 'test-filename',
          encrypted_data: 'test-encrypted-data',
        )

        result = IrsAttemptsEventsBatchJob.perform_now(start_time)

        expect(result).not_to be_nil
        expect(result[:filename]).to eq(
          "s3://#{bucket_name}/#{envelope_encryptor_result[:filename]}",
        )

        expect(result[:iv]).to eq(
          Base64.strict_encode64(envelope_encryptor_result[:iv]),
        )

        expect(result[:encrypted_key]).to eq(
          Base64.strict_encode64(envelope_encryptor_result[:encrypted_key]),
        )

        expect(result[:requested_time]).to eq(start_time)

        # decrypted_result = IrsAttemptsApi::EnvelopeEncryptor.decrypt(
        #  encrypted_data: file_data,
        #  key: final_key, iv: result[:encryptor_result].iv
        # )

        # events_jwes = events.pluck(:jwe)

        # expect(decrypted_result).to eq(events_jwes.join("\r\n"))
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
end
