require 'rails_helper'

describe Encryption::Encryptors::SessionEncryptor do
  let(:plaintext) { '{ "foo": "bar" }' }

  describe '#encrypt' do
    it 'returns ciphertext created by the deprecated session encryptor' do
      expected_ciphertext = '123abc'

      deprecated_encryptor = Encryption::Encryptors::DeprecatedSessionEncryptor.new
      expect(deprecated_encryptor).to receive(:encrypt).
        with(plaintext).
        and_return(expected_ciphertext)
      expect(Encryption::Encryptors::DeprecatedSessionEncryptor).to receive(:new).
        and_return(deprecated_encryptor)

      ciphertext = subject.encrypt(plaintext)

      expect(ciphertext).to eq(expected_ciphertext)
    end
  end

  describe '#decrypt' do
    context 'with a legacy ciphertext' do
      let(:ciphertext) { Encryption::Encryptors::DeprecatedSessionEncryptor.new.encrypt(plaintext) }

      it 'decrypts the ciphertext' do
        expect(subject.decrypt(ciphertext)).to eq(plaintext)
      end
    end

    context 'with a 2L-KMS ciphertext' do
      let(:ciphertext) do
        key = Figaro.env.session_encryption_key[0...32]
        aes_ciphertext = Encryption::Encryptors::AesEncryptor.new.encrypt(plaintext, key)
        kms_ciphertext = Encryption::KmsClient.new.encrypt(aes_ciphertext)
        Base64.strict_encode64(kms_ciphertext)
      end

      it 'decrypts the ciphertext' do
        expect(subject.decrypt(ciphertext)).to eq(plaintext)
      end
    end
  end
end
