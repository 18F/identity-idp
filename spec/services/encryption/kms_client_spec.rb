require 'rails_helper'

describe Encryption::KmsClient do
  before do
    stub_mapped_aws_kms_client(
      'a' * 3000 => 'kms1',
      'b' * 3000 => 'kms2',
      'c' * 3000 => 'kms3',
    )

    encryptor = Encryption::Encryptors::AesEncryptor.new
    {
      'a' * 3000 => 'local1',
      'b' * 3000 => 'local2',
      'c' * 3000 => 'local3',
    }.each do |plaintext, ciphertext|
      allow(encryptor).to receive(:encrypt).
        with(plaintext, local_encryption_key).
        and_return(ciphertext)
      allow(encryptor).to receive(:decrypt).
        with(ciphertext, local_encryption_key).
        and_return(plaintext)
    end
    allow(Encryption::Encryptors::AesEncryptor).to receive(:new).and_return(encryptor)

    allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
  end

  let(:plaintext) { 'a' * 3000 + 'b' * 3000 + 'c' * 3000 }
  let(:encryption_context) { { 'context' => 'attribute-bundle', 'user_id' => '123-abc-456-def' } }

  let(:local_encryption_key) do
    OpenSSL::HMAC.digest(
      'sha256',
      Figaro.env.password_pepper,
      '123-abc-456-defattribute-bundlecontextuser_id',
    )
  end

  let(:kms_ciphertext) do
    'KMSc' + %w[kms1 kms2 kms3].map { |c| Base64.strict_encode64(c) }.to_json
  end
  let(:local_ciphertext) do
    'LOCc' + %w[local1 local2 local3].map { |c| Base64.strict_encode64(c) }.to_json
  end

  let(:kms_enabled) { true }

  describe '#encrypt' do
    context 'with KMS enabled' do
      it 'encrypts with KMS' do
        result = subject.encrypt(plaintext, encryption_context)

        expect(result).to eq(kms_ciphertext)
      end
    end

    context 'with KMS disabled' do
      let(:kms_enabled) { false }

      it 'encrypts with a local key' do
        result = subject.encrypt(plaintext, encryption_context)

        expect(result).to eq(local_ciphertext)
      end
    end

    it 'logs the context' do
      expect(Encryption::KmsLogger).to receive(:log).with(:encrypt, encryption_context)

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
      it 'decrypts the ciphertext with a local key' do
        result = subject.decrypt(local_ciphertext, encryption_context)

        expect(result).to eq(plaintext)
      end
    end

    context 'with a contextless ciphertext' do
      before do
        contextless_client = Encryption::ContextlessKmsClient.new
        allow(contextless_client).to receive(:decrypt).
          with('KMSx123abc').
          and_return('plaintext')
        allow(contextless_client).to receive(:decrypt).
          with('123abc').
          and_return('plaintext')
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
      expect(Encryption::KmsLogger).to receive(:log).with(:decrypt, encryption_context)

      subject.decrypt(kms_ciphertext, encryption_context)
    end
  end
end
