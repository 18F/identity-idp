require 'rails_helper'

describe Pii::KeyMaker do
  let(:password) { 'sekrit' }
  let(:salt) { 'mmmm salty' }

  describe '#new' do
    it 'automatically loads the server-wide signing key' do
      expect(subject.signing_key).to be_a OpenSSL::PKey::RSA
    end
  end

  describe '#rsa_key' do
    it 'returns a OpenSSL::PKey::RSA' do
      pem = subject.generate_rsa(password)

      expect(described_class.rsa_key(pem, password)).to be_a OpenSSL::PKey::RSA
    end
  end

  describe '#generate_rsa' do
    it 'returns a RSA PEM string' do
      pem = subject.generate_rsa(password)

      expect(pem).to be_a String
      expect(pem).to match 'RSA PRIVATE KEY'
      expect(pem).to match 'AES-256-CBC'
    end
  end

  describe '#generate_aes' do
    it 'returns a AES CEK based on passphrase+salt' do
      cek = subject.generate_aes(password, salt)

      expect(cek).to be_a String
      expect(cek).to eq '04a54b00d4e15cf5fc8830ba60b57a1fe6da9e76f54ccf1e26548340e5a98ccd'
    end
  end
end
