require 'rails_helper'

describe Pii::PasswordEncryptor do
  let(:password) { 'sekrit' }
  let(:salt) { SecureRandom.uuid }
  let(:key_maker) { Pii::KeyMaker.new }
  let(:plaintext) { 'four score and seven years ago' }
  subject { Pii::PasswordEncryptor.new(key_maker) }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt(plaintext, password, salt)

      expect(encrypted).to_not match plaintext
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt(plaintext, password, salt)

      expect(subject.decrypt(encrypted, password, salt)).to eq plaintext
    end

    it 'requires same password used for encrypt' do
      encrypted = subject.encrypt(plaintext, password, salt)

      expect do
        subject.decrypt(encrypted, 'different password', salt)
      end.to raise_error OpenSSL::Cipher::CipherError
    end
  end
end
