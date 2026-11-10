require 'rails_helper'

RSpec.describe Encryption::Encryptors::DocumentArtifactEncryptor do
  let(:user_uuid) { SecureRandom.uuid }
  let(:plaintext) { Base64.strict_encode64(SecureRandom.bytes(32)) }

  subject(:encryptor) { described_class.new(user_uuid:) }

  describe '#initialize' do
    it 'requires the person the row belongs to' do
      expect { described_class.new(user_uuid: nil) }.to raise_error(ArgumentError)
      expect { described_class.new(user_uuid: '') }.to raise_error(ArgumentError)
    end
  end

  describe '#encrypt and #decrypt' do
    it 'round-trips through the KMS client' do
      ciphertext = encryptor.encrypt(plaintext)

      expect(ciphertext).not_to include(plaintext)
      expect(encryptor.decrypt(ciphertext)).to eq(plaintext)
    end

    it 'wraps with the multi-region KMS key under a context naming the person' do
      kms_client = instance_double(Encryption::KmsClient)
      allow(Encryption::KmsClient).to receive(:new)
        .with(kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id)
        .and_return(kms_client)
      expected_context = { 'context' => 'document-artifact-encryption', 'user_uuid' => user_uuid }
      allow(kms_client).to receive(:encrypt).with(plaintext, expected_context).and_return('KMSc[]')
      allow(kms_client).to receive(:decrypt).with('KMSc[]', expected_context).and_return(plaintext)

      expect(encryptor.encrypt(plaintext)).to eq('KMSc[]')
      expect(encryptor.decrypt('KMSc[]')).to eq(plaintext)
    end

    it 'does not decrypt a ciphertext wrapped for another person' do
      ciphertext = encryptor.encrypt(plaintext)
      other = described_class.new(user_uuid: SecureRandom.uuid)

      expect { other.decrypt(ciphertext) }.to raise_error(Encryption::EncryptionError)
    end

    it 'refuses a ciphertext that KMS did not produce' do
      legacy = Encryption::Encryptors::AttributeEncryptor.new.encrypt(plaintext)

      expect { encryptor.decrypt(legacy) }
        .to raise_error(Encryption::EncryptionError, /not wrapped by KMS/)
    end

    context 'when KMS is in use' do
      let!(:stubbed_kms) { stub_aws_kms_client }

      before do
        stub_const(
          'Encryption::KmsClient::KMS_CLIENT_POOL',
          FakeConnectionPool.new { Aws::KMS::Client.new(region: 'us-west-2') },
        )
        allow(FeatureManagement).to receive(:use_kms?).and_return(true)
      end

      it 'wraps and unwraps through KMS with a KMS-prefixed ciphertext' do
        plaintext_from_kms, ciphertext_from_kms = stubbed_kms

        ciphertext = encryptor.encrypt(plaintext)

        expect(ciphertext).to start_with('KMSc')
        expect(ciphertext).to include(Base64.strict_encode64(ciphertext_from_kms))
        expect(encryptor.decrypt(ciphertext)).to eq(plaintext_from_kms)
      end
    end
  end
end
