require 'rails_helper'

describe Pii::Cipher do
  let(:plaintext) { 'some long secret' }
  let(:cek) { SecureRandom.uuid }

  describe '#encrypt' do
    it 'returns AES-encrypted string' do
      ciphertext = subject.encrypt(plaintext, cek)

      expect(ciphertext).to_not match plaintext
      expect(ciphertext).to be_a String
    end
  end

  describe '#decrypt' do
    it 'returns plaintext' do
      ciphertext = subject.encrypt(plaintext, cek)

      expect(subject.decrypt(ciphertext, cek)).to eq plaintext
    end
  end

  describe '#random_key' do
    it 'returns random 256 bit string' do
      expect(subject.random_key).to be_a String
      expect(subject.random_key.length).to eq 32
    end
  end
end
