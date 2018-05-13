require 'rails_helper'

describe Pii::PasswordEncryptor do
  let(:password) { 'sekrit' }
  let(:salt) { SecureRandom.uuid }
  let(:user_access_key) { Encryption::UserAccessKey.new(password: password, salt: salt) }
  let(:plaintext) { 'four score and seven years ago' }

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext, user_access_key)

      expect(ciphertext).to_not match plaintext
    end

    it 'only builds encrypted key once per user_access_key' do
      uak = Encryption::UserAccessKey.new(password: password, salt: salt)

      expect(uak.unlocked?).to eq false

      ciphertext_one = subject.encrypt(plaintext, uak)

      expect(uak.unlocked?).to eq true
      expect(uak).to_not receive(:build)

      ciphertext_two = subject.encrypt(plaintext, uak)

      expect(ciphertext_one).to_not eq ciphertext_two
      expect(subject.decrypt(ciphertext_one, uak)).to eq subject.decrypt(ciphertext_two, uak)
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      ciphertext = subject.encrypt(plaintext, user_access_key)

      expect(subject.decrypt(ciphertext, user_access_key)).to eq plaintext
    end

    it 'requires same password used for encrypt' do
      ciphertext = subject.encrypt(plaintext, user_access_key)
      different_user_access_key = Encryption::UserAccessKey.new(password: 'different password', salt: salt)

      expect { subject.decrypt(ciphertext, different_user_access_key) }.
        to raise_error Pii::EncryptionError
    end
  end
end
