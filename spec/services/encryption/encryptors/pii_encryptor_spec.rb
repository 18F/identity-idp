require 'rails_helper'

describe Encryption::Encryptors::PiiEncryptor do
  let(:password) { 'password' }
  let(:salt) { 'n-pepa' }
  let(:plaintext) { 'Oooh baby baby' }

  subject { described_class.new(password: password, salt: salt) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to_not match plaintext
    end

    it 'uses the user access key encryptor to encrypt the plaintext' do
      user_access_key = double(Encryption::UserAccessKey)
      expect(Encryption::UserAccessKey).to receive(:new).
        with(password: password, salt: salt, cost: nil).
        and_return(user_access_key)
      encryptor = double(Encryption::Encryptors::UserAccessKeyEncryptor)
      expect(Encryption::Encryptors::UserAccessKeyEncryptor).to receive(:new).
        with(user_access_key).
        and_return(encryptor)
      expect(encryptor).to receive(:encrypt).with(plaintext).and_return('ciphertext')

      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to eq('ciphertext')
    end
  end

  describe '#decrypt' do
    it 'returns the original text' do
      ciphertext = subject.encrypt(plaintext)
      decrypted_ciphertext = subject.decrypt(ciphertext)

      expect(decrypted_ciphertext).to eq(plaintext)
    end

    it 'requires the same password used for encrypt' do
      ciphertext = subject.encrypt(plaintext)
      new_encryptor = described_class.new(password: 'This is not the passowrd', salt: salt)

      expect { new_encryptor.decrypt(ciphertext) }.to raise_error Pii::EncryptionError
    end

    it 'uses the user access key to decrypt the contents' do
      user_access_key = double(Encryption::UserAccessKey)
      expect(Encryption::UserAccessKey).to receive(:new).
        with(password: password, salt: salt, cost: nil).
        and_return(user_access_key)
      encryptor = double(Encryption::Encryptors::UserAccessKeyEncryptor)
      expect(Encryption::Encryptors::UserAccessKeyEncryptor).to receive(:new).
        with(user_access_key).
        and_return(encryptor)
      expect(encryptor).to receive(:decrypt).with('ciphertext').and_return(plaintext)

      result = subject.decrypt('ciphertext')

      expect(result).to eq(plaintext)
    end
  end
end
