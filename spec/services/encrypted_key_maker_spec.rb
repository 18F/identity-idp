require 'rails_helper'

describe EncryptedKeyMaker do
  let(:password) { 'sekrit' }
  let(:salt) { 'mmmm salty' }
  let(:ciphered_key) { SecureRandom.random_bytes(32) }
  let(:random_R) { SecureRandom.random_bytes(32) }
  let(:user_access_key) { UserAccessKey.new(password: password, salt: salt) }
  let(:hash_E) { OpenSSL::Digest::SHA256.hexdigest(user_access_key.z2 + random_R) }
  let(:hash_F) { OpenSSL::Digest::SHA256.hexdigest(hash_E) }

  describe '#make' do
    context 'FeatureManagement.use_kms? is false' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
        allow(Pii::Cipher).to receive(:random_key).and_return(random_R)
      end

      it 'returns hashed password with encrypted random key' do
        user_access_key_encrypted = subject.make(user_access_key)

        expect(user_access_key_encrypted).to be_a UserAccessKey
        expect(user_access_key_encrypted.encrypted_d).to be_a String
        expect(user_access_key_encrypted.hash_e).to eq hash_E
        expect(user_access_key_encrypted.hash_f).to eq hash_F
      end

      it 'raises exception when param is invalid' do
        expect { subject.make('foobar') }.to raise_error RuntimeError
      end
    end

    context 'FeatureManagement.use_kms? is true' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(true)
        allow(Pii::Cipher).to receive(:random_key).and_return(random_R)
        stub_aws_kms_client(random_R, ciphered_key)
      end

      it 'returns CEK based on hashed password' do
        user_access_key_encrypted = subject.make(user_access_key)

        expect(user_access_key_encrypted).to be_a UserAccessKey
        expect(user_access_key_encrypted.encrypted_d).to be_a String
        expect(user_access_key_encrypted.hash_e).to eq hash_E
        expect(user_access_key_encrypted.hash_f).to eq hash_F
      end
    end
  end

  describe '#unlock' do
    context 'FeatureManagement.use_kms? is false' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
        allow(Pii::Cipher).to receive(:random_key).and_return(random_R)
      end

      it 'returns hash_E based on hashed password' do
        subject.make(user_access_key)
        encryption_key = user_access_key.encryption_key

        expect(subject.unlock(user_access_key, encryption_key)).to eq hash_E
      end

      it 'raises exception when params are invalid' do
        expect { subject.unlock(user_access_key, '!@#$%^&*()') }.to raise_error Pii::EncryptionError

        expect { subject.unlock('foobar', 'zzzz') }.to raise_error Pii::EncryptionError
      end
    end

    context 'FeatureManagement.use_kms? is true' do
      before do
        allow(FeatureManagement).to receive(:use_kms?).and_return(true)
        allow(Pii::Cipher).to receive(:random_key).and_return(random_R)
        stub_aws_kms_client(random_R, ciphered_key)
      end

      it 'returns hash_E based on hashed password' do
        subject.make(user_access_key)
        encryption_key = user_access_key.encryption_key

        expect(subject.unlock(user_access_key, encryption_key)).to eq hash_E
      end

      it 'recognizes locally-encrypted legacy keys' do
        allow(FeatureManagement).to receive(:use_kms?).and_return(false)
        subject.make(user_access_key)
        encryption_key = user_access_key.encryption_key

        allow(FeatureManagement).to receive(:use_kms?).and_return(true)
        expect(subject.unlock(user_access_key, encryption_key)).to eq hash_E
      end

      it 'removes KMS ciphertext prefix before deciphering' do
        prefix = EncryptedKeyMaker::KEY_TYPE[:KMS]
        prefixed_ciphertext = prefix + ciphered_key
        aws_client = Aws::KMS::Client.new(region: Figaro.env.aws_region)

        expect(aws_client).to receive(:decrypt).
          with(ciphertext_blob: ciphered_key).and_call_original
        expect(subject).to receive(:aws_client).at_least(:twice).and_return(aws_client)
        expect(user_access_key).to receive(:store_encrypted_key).
          with(prefixed_ciphertext).and_call_original

        subject.make(user_access_key)
        encryption_key = user_access_key.encryption_key
        subject.unlock(user_access_key, encryption_key)
      end
    end
  end
end
