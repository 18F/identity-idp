require 'rails_helper'

describe Encryption::Encryptors::UserAccessKeyEncryptor do
  let(:password) { 'password' }
  let(:salt) { 'n-pepa' }
  let(:plaintext) { 'Oooh baby baby' }
  let(:user_access_key) { Encryption::UserAccessKey.new(password: password, salt: salt) }

  subject { described_class.new(user_access_key) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to_not match plaintext
    end

    it 'only builds the user access key once' do
      expect(user_access_key).to receive(:build).once.and_call_original
      expect(user_access_key).to_not receive(:unlock)

      subject.encrypt(plaintext)
      subject.encrypt(plaintext)
    end
  end

  describe '#decrypt' do
    it 'returns the original text' do
      ciphertext = subject.encrypt(plaintext)
      decrypted_ciphertext = subject.decrypt(ciphertext)

      expect(decrypted_ciphertext).to eq(plaintext)
    end

    it 'requires the same user access key used for encrypt' do
      ciphertext = subject.encrypt(plaintext)
      wrong_key = Encryption::UserAccessKey.new(password: 'This is not the password', salt: salt)
      new_encryptor = described_class.new(wrong_key)

      expect { new_encryptor.decrypt(ciphertext) }.to raise_error Encryption::EncryptionError
    end

    it 'raises an error if the ciphertext is not base64 encoded' do
      expect { subject.decrypt('@@@@@@@') }.to raise_error Encryption::EncryptionError
    end

    it 'only unlocks the user access key once' do
      # Encrypt the plaintext so that user access key is not built by encrypt
      # but encryption instead of being unlocked
      ciphertext = described_class.new(user_access_key.dup).encrypt(plaintext)

      expect(user_access_key).to receive(:unlock).once.and_call_original
      expect(user_access_key).to_not receive(:build)

      subject.decrypt(ciphertext)
      subject.decrypt(ciphertext)
    end

    it 'can decrypt contents created by different user access keys if the password is the same' do
      uak1 = Encryption::UserAccessKey.new(password: password, salt: salt)
      uak2 = Encryption::UserAccessKey.new(password: password, salt: salt)
      payload1 = described_class.new(uak1).encrypt(plaintext)
      payload2 = described_class.new(uak2).encrypt(plaintext)

      expect(payload1).to_not eq(payload2)

      expect(user_access_key).to receive(:unlock).twice.and_call_original

      result1 = subject.decrypt(payload1)
      result2 = subject.decrypt(payload2)

      expect(result1).to eq(plaintext)
      expect(result2).to eq(plaintext)
    end
  end
end
