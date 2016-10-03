require 'rails_helper'

describe Pii::Encryptor do
  let(:password) { 'sekrit' }
  let(:key_maker) { Pii::KeyMaker.new }
  subject { Pii::Encryptor.new }

  describe '#encrypt' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt('foobar', password)

      expect(encrypted).to_not match 'foobar'
    end
  end

  describe '#decrypt' do
    it 'returns original text' do
      encrypted = subject.encrypt('foobar', password)

      expect(subject.decrypt(encrypted, password)).to eq 'foobar'
    end

    it 'rejects tampered text' do
      encrypted = subject.encrypt('foobar', password)
      key, payload = encrypted.split(described_class::DELIMITER)
      payload = Base64.strict_encode64(Base64.strict_decode64(payload) + '123')
      reencrypted = [key, payload].join(described_class::DELIMITER)
      expect { subject.decrypt(reencrypted, password) }.to raise_error OpenSSL::Cipher::CipherError
    end

    it 'requires same password used for encrypt' do
      encrypted = subject.encrypt('foobar', password)

      expect do
        subject.decrypt(encrypted, 'different password')
      end.to raise_error OpenSSL::PKey::RSAError
    end
  end

  describe '#encrypt_with_key' do
    it 'returns encrypted text' do
      encrypted = subject.encrypt_with_key('foobar', key_maker.server_key)

      expect(encrypted).to_not match 'foobar'
    end
  end

  describe '#decrypt_with_key' do
    it 'returns original text' do
      encrypted = subject.encrypt_with_key('foobar', key_maker.server_key)

      expect(subject.decrypt_with_key(encrypted, key_maker.server_key)).to eq 'foobar'
    end

    it 'requires same RSA key used for encrypt_with_key' do
      encrypted = subject.encrypt_with_key('foobar', key_maker.server_key)
      new_key_pem = key_maker.generate('password')
      new_key = Pii::KeyMaker.rsa_key(new_key_pem, 'password')

      expect do
        subject.decrypt_with_key(encrypted, new_key)
      end.to raise_error OpenSSL::PKey::RSAError
    end
  end
end
