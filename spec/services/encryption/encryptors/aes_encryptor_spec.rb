require 'rails_helper'

describe Encryption::Encryptors::AesEncryptor do
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
  end
end
