require 'rails_helper'

describe Pii::KeyMaker do
  let(:password) { 'sekrit' }

  describe '#new' do
    it 'automatically loads the server-wide private key' do
      expect(subject.server_key).to be_a OpenSSL::PKey::RSA
    end
  end

  describe '#rsa_key' do
    it 'returns a OpenSSL::PKey::RSA' do
      pem = subject.generate(password)

      expect(described_class.rsa_key(pem, password)).to be_a OpenSSL::PKey::RSA
    end
  end

  describe '#generate' do
    it 'returns a RSA PEM string' do
      pem = subject.generate(password)

      expect(pem).to be_a String
      expect(pem).to match 'RSA PRIVATE KEY'
      expect(pem).to match 'AES-256-CBC'
    end
  end
end
