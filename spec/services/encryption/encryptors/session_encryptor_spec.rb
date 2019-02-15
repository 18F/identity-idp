require 'rails_helper'

describe Encryption::Encryptors::SessionEncryptor do
  let(:plaintext) { '{ "foo": "bar" }' }

  describe '#encrypt' do
    it 'returns a KMS wrapped AES encrypted ciphertext' do
      aes_encryptor = instance_double(Encryption::Encryptors::AesEncryptor)
      kms_client = instance_double(Encryption::ContextlessKmsClient)
      allow(aes_encryptor).to receive(:encrypt).
        with(plaintext, Figaro.env.session_encryption_key[0...32]).
        and_return('aes output')
      allow(kms_client).to receive(:encrypt).
        with('aes output').
        and_return('kms output')
      allow(Encryption::Encryptors::AesEncryptor).to receive(:new).and_return(aes_encryptor)
      allow(Encryption::ContextlessKmsClient).to receive(:new).and_return(kms_client)

      expected_ciphertext = Base64.strict_encode64('kms output')

      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to eq(expected_ciphertext)
    end
  end

  describe '#decrypt' do
    let(:ciphertext) { Encryption::Encryptors::SessionEncryptor.new.encrypt(plaintext) }

    it 'decrypts the ciphertext' do
      expect(subject.decrypt(ciphertext)).to eq(plaintext)
    end
  end
end
