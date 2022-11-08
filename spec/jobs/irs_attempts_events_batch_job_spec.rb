require 'rails_helper'

RSpec.describe IrsAttemptsEventsBatchJob, type: :job do
  describe '#perform' do
    context 'IRS attempts API is enabled' do
      let(:start_time) { Time.new(2020, 1, 1, 12, 0, 0, 'UTC') }
      let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
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

      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
          and_return(Base64.strict_encode64(private_key.public_key.to_der))

        Dir.mktmpdir do |dir|
          @dir_path = dir
        end

        travel_to start_time + 1.hour

        redis_client = IrsAttemptsApi::RedisClient.new
        events.each do |event|
          redis_client.write_event(
            event_key: event[:event_key], jwe: event[:jwe],
            timestamp: event[:timestamp]
          )
        end
      end

      it 'batches and writes attempt events to an encrypted file' do
        result = IrsAttemptsEventsBatchJob.perform_now(timestamp: start_time, dir_path: @dir_path)
        expect(result[:file_path]).not_to be_nil

        file_data = File.open(result[:file_path], 'rb') do |file|
          file.read
        end

        final_key = private_key.private_decrypt(result[:encryptor_result].encrypted_key)

        decrypted_result = IrsAttemptsApi::EnvelopeEncryptor.decrypt(
          encrypted_data: file_data,
          key: final_key, iv: result[:encryptor_result].iv
        )

        events_jwes = events.pluck(:jwe)

        expect(decrypted_result).to eq(events_jwes.join("\r\n"))
      end
    end

    context 'IRS attempts API is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)
      end

      it 'returns nil' do
        file_path = IrsAttemptsEventsBatchJob.perform_now
        expect(file_path).to eq(nil)
      end
    end
  end
end
