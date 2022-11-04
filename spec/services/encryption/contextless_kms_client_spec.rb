require 'rails_helper'

describe Encryption::ContextlessKmsClient do
  let(:password_pepper) { '1' * 32 }
  let(:local_plaintext) { 'local plaintext' }
  let(:local_ciphertext) { 'local ciphertext' }

  before do
    stub_const(
      'Encryption::ContextlessKmsClient::KMS_CLIENT_POOL',
      AwsKmsClientHelper::FakeConnectionPool.new { Aws::KMS::Client.new },
    )
  end

  context 'with kms plaintext less than 4k' do
    let(:kms_plaintext) { 'kms plaintext' }
    let(:kms_ciphertext) { 'kms ciphertext' }
    let(:kms_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:password_pepper).and_return(password_pepper)

      encryptor = Encryption::Encryptors::AesEncryptor.new
      allow(encryptor).to receive(:encrypt).
        with(local_plaintext, password_pepper).
        and_return(local_ciphertext)
      allow(encryptor).to receive(:decrypt).
        with(local_ciphertext, password_pepper).
        and_return(local_plaintext)
      allow(Encryption::Encryptors::AesEncryptor).to receive(:new).and_return(encryptor)

      stub_aws_kms_client(kms_plaintext, kms_ciphertext)
      allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
    end

    describe '#encrypt' do
      context 'with KMS enabled' do
        it 'uses KMS to encrypt the plaintext' do
          result = subject.encrypt(kms_plaintext)

          expect(result).to eq('KMSx' + kms_ciphertext)
        end
      end

      context 'without KMS enabled' do
        let(:kms_enabled) { false }

        it 'uses the password pepper to encrypt the plaintext and signs it' do
          result = subject.encrypt(local_plaintext)

          expect(result).to eq(local_ciphertext)
        end
      end
    end

    describe '#decrypt' do
      context 'with KMS enabled' do
        it 'uses KMS to decrypt a ciphertext encrypted with KMS' do
          result = subject.decrypt('KMSx' + kms_ciphertext)

          expect(result).to eq(kms_plaintext)
        end

        it 'uses the password pepper to decrypt a legacy ciphertext encrypted without KMS' do
          result = subject.decrypt(local_ciphertext)

          expect(result).to eq(local_plaintext)
        end
      end

      context 'without KMS enabled' do
        let(:kms_enabled) { false }

        it 'uses the password pepper to decrypt a ciphertext' do
          result = subject.decrypt(local_ciphertext)

          expect(result).to eq(local_plaintext)
        end
      end
    end

    describe '#looks_like_kms?' do
      it 'returns true for kms encrypted data' do
        expect(subject.class.looks_like_kms?('KMSx' + kms_ciphertext)).to eq(true)
      end

      it 'returns false for non kms encrypted data' do
        expect(subject.class.looks_like_kms?('abcdef.' + kms_ciphertext)).to eq(false)
      end
    end
  end

  context 'with kms plaintext greater than 4k' do
    let(:long_kms_plaintext) { SecureRandom.random_bytes(4096 * 1.8) }
    let(:long_kms_plaintext_bytesize) { long_kms_plaintext.bytesize }
    let(:long_kms_plaintext_chunksize) { long_kms_plaintext_bytesize / 2 }
    let(:kms_ciphertext) { %w[chunk1 chunk2].map { |c| Base64.strict_encode64(c) }.to_json }
    let(:kms_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:password_pepper).and_return(password_pepper)

      encryptor = Encryption::Encryptors::AesEncryptor.new
      allow(encryptor).to receive(:encrypt).
        with(local_plaintext, password_pepper).
        and_return(local_ciphertext)
      allow(encryptor).to receive(:decrypt).
        with(local_ciphertext, password_pepper).
        and_return(local_plaintext)
      allow(Encryption::Encryptors::AesEncryptor).to receive(:new).and_return(encryptor)

      stub_mapped_aws_kms_client(
        [
          {
            plaintext: long_kms_plaintext[0..long_kms_plaintext_chunksize - 1],
            ciphertext: 'chunk1',
            key_id: IdentityConfig.store.aws_kms_key_id,
            region: IdentityConfig.store.aws_region,
          },
          {
            plaintext: long_kms_plaintext[long_kms_plaintext_chunksize..-1],
            ciphertext: 'chunk2',
            key_id: IdentityConfig.store.aws_kms_key_id,
            region: IdentityConfig.store.aws_region,
          },
        ],
      )
      allow(FeatureManagement).to receive(:use_kms?).and_return(kms_enabled)
    end

    describe '#encrypt' do
      context 'with KMS enabled' do
        it 'uses KMS to encrypt the plaintext' do
          result = subject.encrypt(long_kms_plaintext)

          expect(result).to eq('KMSx' + kms_ciphertext)
        end
      end

      context 'without KMS enabled' do
        let(:kms_enabled) { false }

        it 'uses the password pepper to encrypt the plaintext and signs it' do
          result = subject.encrypt(local_plaintext)

          expect(result).to eq(local_ciphertext)
        end
      end

      it 'logs the encryption' do
        expect(Encryption::KmsLogger).to receive(:log).with(:encrypt)

        subject.encrypt(long_kms_plaintext)
      end
    end

    describe '#decrypt' do
      context 'with KMS enabled' do
        it 'uses KMS to decrypt a ciphertext encrypted with KMS' do
          result = subject.decrypt('KMSx' + kms_ciphertext)

          expect(result).to eq(long_kms_plaintext)
        end

        it 'uses the password pepper to decrypt a legacy ciphertext encrypted without KMS' do
          result = subject.decrypt(local_ciphertext)

          expect(result).to eq(local_plaintext)
        end
      end

      context 'without KMS enabled' do
        let(:kms_enabled) { false }

        it 'uses the password pepper to decrypt a ciphertext' do
          result = subject.decrypt(local_ciphertext)

          expect(result).to eq(local_plaintext)
        end
      end

      it 'logs the decryption' do
        expect(Encryption::KmsLogger).to receive(:log).with(:decrypt)

        subject.decrypt('KMSx' + kms_ciphertext)
      end
    end

    describe '#looks_like_kms?' do
      it 'returns true for kms encrypted data' do
        expect(subject.class.looks_like_kms?('KMSx' + kms_ciphertext)).to eq(true)
      end

      it 'returns false for non kms encrypted data' do
        expect(subject.class.looks_like_kms?('abcdef.' + kms_ciphertext)).to eq(false)
      end
    end
  end
end
