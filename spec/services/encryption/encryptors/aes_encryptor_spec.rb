require 'rails_helper'

RSpec.describe Encryption::Encryptors::AesEncryptor do
  let(:aes_cek) { SecureRandom.random_bytes(32) }
  let(:plaintext) { 'four score and seven years ago' }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext, aes_cek)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext, aes_cek)

      expect(subject.decrypt(encrypted, aes_cek)).to eq plaintext
    end

    it 'requires same password used for encrypt' do
      encrypted = subject.encrypt(plaintext, aes_cek)
      diff_cek = SecureRandom.random_bytes(32)

      expect { subject.decrypt(encrypted, diff_cek) }.to raise_error Encryption::EncryptionError
    end

    it 'raises EncryptionError if ciphertext is not Base64 encoded' do
      expect { subject.decrypt('!', aes_cek) }.to raise_error(
        Encryption::EncryptionError,
        'ciphertext is invalid',
      )
    end

    it 'raises EncryptionError if decrypted text is not Base64 encoded' do
      cipher = Encryption::AesCipher.new
      encrypted = cipher.encrypt("\x00", aes_cek)
      encoded_encrypted = Base64.strict_encode64(encrypted)
      expect { subject.decrypt(encoded_encrypted, aes_cek) }.to raise_error(
        Encryption::EncryptionError,
        'payload is invalid',
      )
    end
  end
end
