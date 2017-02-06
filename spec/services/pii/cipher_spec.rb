require 'rails_helper'

describe Pii::Cipher do
  let(:plaintext) { 'some long secret' }
  let(:cek) { SecureRandom.uuid }

  describe '#encrypt' do
    it 'returns JSON string containing AES-encrypted ciphertext' do
      ciphertext = subject.encrypt(plaintext, cek)

      expect(ciphertext).to_not match plaintext
      expect(ciphertext).to be_a String
      expect { JSON.parse(ciphertext) }.to_not raise_error
    end
  end

  describe '#decrypt' do
    it 'returns plaintext' do
      ciphertext = subject.encrypt(plaintext, cek)

      expect(subject.decrypt(ciphertext, cek)).to eq plaintext
    end

    it 'raises error on invalid input' do
      ciphertext = subject.encrypt(plaintext, cek)
      ciphertext += 'foo'

      expect { subject.decrypt(ciphertext, cek) }.to raise_error Pii::EncryptionError
    end
  end

  describe '#random_key' do
    it 'returns random 256 bit string' do
      expect(described_class.random_key).to be_a String
      expect(described_class.random_key.length).to eq 32
    end
  end
end
