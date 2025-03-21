require 'rails_helper'

RSpec.describe Encryption::KmsClient do
  around do |example|
    freeze_time { example.run }
  end

  before do
    stub_const(
      'Encryption::KmsClient::KMS_CLIENT_POOL',
      FakeConnectionPool.new { aws_kms_client },
    )

    # rubocop:disable Layout/LineLength
    if kms_enabled
      stub_mapped_aws_kms_client(
        [
          { plaintext: 'a' * 3000, ciphertext: 'us-north-1:kms1', key_id: key_id, region: 'us-north-1' },
          { plaintext: 'b' * 3000, ciphertext: 'us-north-1:kms2', key_id: key_id, region: 'us-north-1' },
          { plaintext: 'c' * 3000, ciphertext: 'us-north-1:kms3', key_id: key_id, region: 'us-north-1' },
        ],
      )
    end
    # rubocop:enable Layout/LineLength

    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
    allow(IdentityConfig.store).to receive(:aws_region).and_return(aws_region)
    allow(IdentityConfig.store).to receive(:aws_kms_key_id).and_return(key_id)
  end

  let(:aws_kms_client) { Aws::KMS::Client.new(region: aws_region) }
  let(:key_id) { 'key1' }
  let(:plaintext) { 'a' * 3000 + 'b' * 3000 + 'c' * 3000 }
  let(:encryption_context) { { 'context' => 'attribute-bundle', 'user_id' => '123-abc-456-def' } }
  let(:log_timestamp) { Time.utc(2025, 2, 28, 15, 30, 1) }

  let(:aws_region) { 'us-north-1' }

  let(:kms_ciphertext) do
    'KMSc' + %w[
      us-north-1:kms1
      us-north-1:kms2
      us-north-1:kms3
    ].map { |c| Base64.strict_encode64(c) }.to_json
  end

  let(:kms_enabled) { true }

  describe '#encrypt' do
    context 'with KMS enabled' do
      it 'encrypts with KMS' do
        result = subject.encrypt(plaintext, encryption_context)
        expect(result).to eq(kms_ciphertext)
      end
    end

    context 'with a KMS key ID specified' do
      subject { described_class.new(kms_key_id: 'custom-key-id') }

      before do
        stub_mapped_aws_kms_client(
          [
            # rubocop:disable Layout/LineLength
            { plaintext: 'a' * 3000, ciphertext: 'us-north-1:kms1', key_id: 'custom-key-id', region: 'us-north-1' },
            { plaintext: 'b' * 3000, ciphertext: 'us-north-1:kms2', key_id: 'custom-key-id', region: 'us-north-1' },
            { plaintext: 'c' * 3000, ciphertext: 'us-north-1:kms3', key_id: 'custom-key-id', region: 'us-north-1' },
            # rubocop:enable Layout/LineLength
          ],
        )
      end

      it 'encrypts with the specified key ID' do
        result = subject.encrypt(plaintext, encryption_context)

        expect(result).to eq(kms_ciphertext)
        expect(aws_kms_client.api_requests.count).to eq(3)

        aws_kms_client.api_requests.each do |api_request|
          expect(api_request[:params][:key_id]).to eq('custom-key-id')
        end
      end
    end

    context 'with KMS disabled' do
      let(:kms_enabled) { false }

      it 'encrypts with a local key' do
        result = subject.encrypt(plaintext, encryption_context)

        expect(result).to_not include(plaintext)
      end
    end

    it 'logs the context' do
      expect(Encryption::KmsLogger).to receive(:log).with(
        action: :encrypt,
        timestamp: Time.zone.now,
        context: encryption_context,
        key_id: subject.kms_key_id,
      )

      subject.encrypt(plaintext, encryption_context)
    end
  end

  describe '#decrypt' do
    context 'with a ciphertext encrypted with KMS' do
      it 'decrypts the ciphertext with KMS' do
        result = subject.decrypt(kms_ciphertext, encryption_context)
        expect(result).to eq(plaintext)
      end
    end

    context 'with a ciphertext encrypted with a local key' do
      let(:kms_enabled) { false }

      it 'decrypts the ciphertext with a local key' do
        ciphertext = subject.encrypt(plaintext, encryption_context)
        result = subject.decrypt(ciphertext, encryption_context)

        expect(result).to eq(plaintext)
      end
    end

    context 'with a contextless ciphertext' do
      before do
        contextless_client = Encryption::ContextlessKmsClient.new
        allow(contextless_client).to receive(:decrypt)
          .with('KMSx123abc', log_context: encryption_context)
          .and_return('plaintext')
        allow(contextless_client).to receive(:decrypt)
          .with('123abc', log_context: encryption_context)
          .and_return('plaintext')
        allow(Encryption::ContextlessKmsClient).to receive(:new).and_return(contextless_client)
      end

      context 'created with KMS' do
        it 'delegates to the contextless kms client' do
          result = subject.decrypt('KMSx123abc', encryption_context)

          expect(result).to eq('plaintext')
        end
      end

      context 'created with a local key' do
        it 'delegates to the contextless kms client' do
          result = subject.decrypt('123abc', encryption_context)

          expect(result).to eq('plaintext')
        end
      end
    end

    it 'logs the context' do
      expect(Encryption::KmsLogger).to receive(:log).with(
        action: :decrypt,
        timestamp: Time.zone.now,
        context: encryption_context,
        key_id: subject.kms_key_id,
      )
      subject.decrypt(kms_ciphertext, encryption_context)
    end
  end
end
