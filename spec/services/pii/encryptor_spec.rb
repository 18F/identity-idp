require 'rails_helper'

describe Pii::Encryptor do
  let(:aes_cek) { SecureRandom.uuid }
  let(:key_maker) { Pii::KeyMaker.new }
  let(:plaintext) { 'four score and seven years ago' }
  subject { Pii::Encryptor.new(key_maker) }

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
      diff_cek = aes_cek.tr('-', 'z')

      expect do
        subject.decrypt(encrypted, diff_cek)
      end.to raise_error OpenSSL::Cipher::CipherError
    end
  end
end
