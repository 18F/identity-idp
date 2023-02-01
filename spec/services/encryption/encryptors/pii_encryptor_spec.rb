require 'rails_helper'

describe Encryption::Encryptors::PiiEncryptor do
  let(:password) { 'password' }
  let(:plaintext) { 'Oooh baby baby' }

  subject { described_class.new(password) }

  describe Encryption::Encryptors::PiiEncryptor::Ciphertext do
    describe '.parse_from_string' do
      it 'does not blow up with unknown/new keys' do
        blob = Encryption::Encryptors::PiiEncryptor::Ciphertext.new('encrypted_data').to_s
        str = JSON.parse(blob).merge(some_new_field: 'some_new_field').to_json

        ciphertext = Encryption::Encryptors::PiiEncryptor::Ciphertext.parse_from_string(str)
        expect(ciphertext.encrypted_data).to eq('encrypted_data')
      end
    end
  end

  describe '#encrypt' do
    it 'returns encrypted text' do
      ciphertext = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')

      expect(ciphertext).to_not match plaintext
    end

    it 'uses layers KMS and AES to encrypt the plaintext' do
      salt = '0' * 64
      allow(SecureRandom).to receive(:hex).and_call_original
      allow(SecureRandom).to receive(:hex).once.with(32).and_return(salt)

      scrypt_digest = '31' * 32 # hex_encode('1111..')
      decoded_scrypt_digest = '1' * 32

      scrypt_password = instance_double(SCrypt::Password)
      expect(scrypt_password).to receive(:digest).and_return(scrypt_digest)
      expect(SCrypt::Password).to receive(:new).and_return(scrypt_password)

      cipher = instance_double(Encryption::AesCipher)
      expect(Encryption::AesCipher).to receive(:new).and_return(cipher)
      expect(cipher).to receive(:encrypt).
        with(plaintext, decoded_scrypt_digest).
        and_return('aes_ciphertext')

      expect(subject.send(:kms_client)).to receive(:encrypt).
        with('aes_ciphertext', { 'context' => 'pii-encryption', 'user_uuid' => 'uuid-123-abc' }).
        and_return('kms_ciphertext')

      expected_ciphertext = Base64.strict_encode64('kms_ciphertext')

      ciphertext = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')

      expect(ciphertext).to eq(
        {
          encrypted_data: expected_ciphertext,
          salt: salt,
          cost: '800$8$1$',
        }.to_json,
      )
    end
  end

  describe '#decrypt' do
    it 'returns the original text' do
      ciphertext = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')
      decrypted_ciphertext = subject.decrypt(ciphertext, user_uuid: 'uuid-123-abc')

      expect(decrypted_ciphertext).to eq(plaintext)
    end

    it 'requires the same password used for encrypt' do
      ciphertext = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')
      new_encryptor = described_class.new('This is not the passowrd')

      expect { new_encryptor.decrypt(ciphertext, user_uuid: 'uuid-123-abc') }.
        to raise_error Encryption::EncryptionError
    end

    it 'uses layered AES and KMS to decrypt the contents' do
      salt = '0' * 64

      scrypt_digest = '31' * 32 # hex_encode('1111..')
      decoded_scrypt_digest = '1' * 32

      scrypt_password = instance_double(SCrypt::Password)
      expect(scrypt_password).to receive(:digest).and_return(scrypt_digest)
      expect(SCrypt::Password).to receive(:new).and_return(scrypt_password)

      kms_client = instance_double(Encryption::KmsClient)
      expect(Encryption::KmsClient).to receive(:new).and_return(kms_client)
      expect(kms_client).to receive(:decrypt).
        with('kms_ciphertext', { 'context' => 'pii-encryption', 'user_uuid' => 'uuid-123-abc' }).
        and_return('aes_ciphertext')

      cipher = instance_double(Encryption::AesCipher)
      expect(Encryption::AesCipher).to receive(:new).and_return(cipher)
      expect(cipher).to receive(:decrypt).
        with('aes_ciphertext', decoded_scrypt_digest).
        and_return(plaintext)

      result = subject.decrypt(
        {
          encrypted_data: Base64.strict_encode64('kms_ciphertext'),
          salt: salt,
          cost: '800$8$1$',
        }.to_json, user_uuid: 'uuid-123-abc'
      )

      expect(result).to eq(plaintext)
    end
  end
end
