require 'rails_helper'

describe Encryption::Encryptors::SessionEncryptor do
  let(:plaintext) { '{ "foo": "bar" }' }

  describe '#encrypt' do
    it 'returns a KMS wrapped AES encrypted ciphertext' do
      aes_encryptor = instance_double(Encryption::Encryptors::AesEncryptor)
      kms_client = instance_double(Encryption::KmsClient)
      allow(aes_encryptor).to receive(:encrypt).
        with(plaintext, Figaro.env.session_encryption_key[0...32]).
        and_return('aes output')
      allow(kms_client).to receive(:encrypt).
        with('aes output', 'context' => 'session-encryption').
        and_return('kms output')
      allow(Encryption::Encryptors::AesEncryptor).to receive(:new).and_return(aes_encryptor)
      allow(Encryption::KmsClient).to receive(:new).and_return(kms_client)

      expected_ciphertext = Base64.strict_encode64('kms output')

      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to eq(expected_ciphertext)
    end

    it 'sets an encryption context' do
      client = instance_double(Encryption::KmsClient)
      expect(client).to receive(:encrypt).with(
        instance_of(String), 'context' => 'session-encryption'
      ).and_return('kms_ciphertext')
      allow(Encryption::KmsClient).to receive(:new).and_return(client)

      subject.encrypt(plaintext)
    end
  end

  describe '#decrypt' do
    let(:ciphertext) { Encryption::Encryptors::SessionEncryptor.new.encrypt(plaintext) }

    it 'decrypts the ciphertext' do
      expect(subject.decrypt(ciphertext)).to eq(plaintext)
    end
  end
end
