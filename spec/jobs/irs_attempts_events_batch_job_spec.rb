require 'rails_helper'

RSpec.describe IrsAttemptsEventsBatchJob, type: :job do
  describe '#perform' do
    events = { key1: 'SomeEncryptedEvent1' }
    Result = Struct.new(:filename, :iv, :encrypted_key, :encrypted_data, keyword_init: true)

    let(:redis_client) { instance_double(IrsAttemptsApi::RedisClient) }
    let(:envelope_encryptor) { instance_double(IrsAttemptsApi::EnvelopeEncryptor) }

    let(:file_double) { instance_double(File) }

    context 'IRS attempts API is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)

        allow(IrsAttemptsApi::RedisClient).
          to receive(:new).
          and_return(redis_client)

        allow(redis_client).
          to receive(:read_events).
          and_return(events)

        allow(IrsAttemptsApi::EnvelopeEncryptor).
          to receive(:encrypt).
          and_return(
            Result.new(
              filename: 'test_filename',
              encrypted_data: 'EnvelopeEncryptedEvents',
            ),
          )

        allow(File).
          to receive(:exists?).
          and_return(true)

        allow(File).
          to receive(:open).
          and_return(file_double)

        allow(file_double).
          to receive(:write)

        allow(file_double).
          to receive(:close)

        allow(file_double).
          to receive(:path).
          and_return('./attempts_api_output/test_filename')
      end

      it 'batches and writes attempt events to an encrypted file' do
        # event hash values are read from redis,
        # then wrote to a file that then is passed through envelope encryptor

        # batch job is run hourly by default
        # batches events from the beginning of the previous hour by default
        # file is stored at:  "./attempts_api_output" by default

        file_path = IrsAttemptsEventsBatchJob.perform_now

        expect(file_path).to eq('./attempts_api_output/test_filename')
      end
    end

    context 'IRS attempts API is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)
      end

      it 'returns nil if IRS attempts API is not enabled' do
        file_path = IrsAttemptsEventsBatchJob.perform_now
        expect(file_path).to eq(nil)
      end
    end
  end
end
