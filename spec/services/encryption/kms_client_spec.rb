require 'rails_helper'

describe Encryption::KmsClient do
  let(:password_pepper) { '1' * 32 }
  let(:local_plaintext) { 'local plaintext' }
  let(:local_ciphertext) { 'local ciphertext' }
  let(:kms_plaintext) { 'kms plaintext' }
  let(:kms_ciphertext) { 'kms ciphertext' }
  let(:kms_enabled) { true }

  before do
    allow(Figaro.env).to receive(:password_pepper).and_return(password_pepper)

    encryptor = Pii::Encryptor.new
    allow(encryptor).to receive(:encrypt).
      with(local_plaintext, password_pepper).
      and_return(local_ciphertext)
    allow(encryptor).to receive(:decrypt).
      with(local_ciphertext, password_pepper).
      and_return(local_plaintext)
    allow(Pii::Encryptor).to receive(:new).and_return(encryptor)

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
end
