require 'rails_helper'

describe Pii::PasswordEncryptor do
  let(:password) { 'sekrit' }
  let(:salt) { SecureRandom.uuid }
  let(:user_access_key) { UserAccessKey.new(password, salt) }
  let(:plaintext) { 'four score and seven years ago' }

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext, user_access_key)

      expect(ciphertext).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      ciphertext = subject.encrypt(plaintext, user_access_key)

      expect(subject.decrypt(ciphertext, user_access_key)).to eq plaintext
    end

    it 'requires same password used for encrypt' do
      ciphertext = subject.encrypt(plaintext, user_access_key)
      different_user_access_key = UserAccessKey.new('different password', salt)

      expect do
        subject.decrypt(ciphertext, different_user_access_key)
      end.to raise_error Pii::EncryptionError
    end
  end
end
