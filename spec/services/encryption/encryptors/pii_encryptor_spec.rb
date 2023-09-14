require 'rails_helper'

RSpec.describe Encryption::Encryptors::PiiEncryptor do
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
      ciphertext, ciphertext_multi_region = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')

      expect(ciphertext).to_not match plaintext
      expect(ciphertext_multi_region).to_not match plaintext
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

      cipher = subject.send(:aes_cipher)
      expect(cipher).to receive(:encrypt).
        with(plaintext, decoded_scrypt_digest).
        and_return('aes_ciphertext')

      single_region_kms_client = subject.send(:single_region_kms_client)
      multi_region_kms_client = subject.send(:multi_region_kms_client)

      expect(single_region_kms_client.kms_key_id).to eq(
        IdentityConfig.store.aws_kms_key_id,
      )
      expect(multi_region_kms_client.kms_key_id).to eq(
        IdentityConfig.store.aws_kms_multi_region_key_id,
      )

      expect(single_region_kms_client).to receive(:encrypt).
        with('aes_ciphertext', { 'context' => 'pii-encryption', 'user_uuid' => 'uuid-123-abc' }).
        and_return('single_region_kms_ciphertext')
      expect(multi_region_kms_client).to receive(:encrypt).
        with('aes_ciphertext', { 'context' => 'pii-encryption', 'user_uuid' => 'uuid-123-abc' }).
        and_return('multi_region_kms_ciphertext')

      ciphertext_single_region, ciphertext_multi_region = subject.encrypt(
        plaintext, user_uuid: 'uuid-123-abc'
      )

      expect(ciphertext_single_region).to eq(
        {
          encrypted_data: Base64.strict_encode64('single_region_kms_ciphertext'),
          salt: salt,
          cost: '800$8$1$',
        }.to_json,
      )
      expect(ciphertext_multi_region).to eq(
        {
          encrypted_data: Base64.strict_encode64('multi_region_kms_ciphertext'),
          salt: salt,
          cost: '800$8$1$',
        }.to_json,
      )
    end
  end

  describe '#decrypt' do
    it 'returns the original text' do
      ciphertext_pair = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')

      decrypted_ciphertext = subject.decrypt(ciphertext_pair, user_uuid: 'uuid-123-abc')

      expect(decrypted_ciphertext).to eq(plaintext)
    end

    it 'requires the same password used for encrypt' do
      ciphertext_pair = subject.encrypt(plaintext, user_uuid: 'uuid-123-abc')
      new_encryptor = described_class.new('This is not the passowrd')

      expect { new_encryptor.decrypt(ciphertext_pair, user_uuid: 'uuid-123-abc') }.
        to raise_error Encryption::EncryptionError
    end

    it 'uses layered AES and KMS to decrypt the contents' do
      salt = '0' * 64

      scrypt_digest = '31' * 32 # hex_encode('1111..')
      decoded_scrypt_digest = '1' * 32

      scrypt_password = instance_double(SCrypt::Password)
      expect(scrypt_password).to receive(:digest).and_return(scrypt_digest)
      expect(SCrypt::Password).to receive(:new).and_return(scrypt_password)

      kms_client = subject.send(:multi_region_kms_client)
      expect(kms_client).to receive(:decrypt).
        with('kms_ciphertext_mr', { 'context' => 'pii-encryption', 'user_uuid' => 'uuid-123-abc' }).
        and_return('aes_ciphertext')

      cipher = subject.send(:aes_cipher)
      expect(cipher).to receive(:decrypt).
        with('aes_ciphertext', decoded_scrypt_digest).
        and_return(plaintext)

      ciphertext_pair = Encryption::RegionalCiphertextPair.new(
        single_region_ciphertext: {
          encrypted_data: Base64.strict_encode64('kms_ciphertext_sr'),
          salt: salt,
          cost: '800$8$1$',
        }.to_json,
        multi_region_ciphertext: {
          encrypted_data: Base64.strict_encode64('kms_ciphertext_mr'),
          salt: salt,
          cost: '800$8$1$',
        }.to_json,
      )

      result = subject.decrypt(ciphertext_pair, user_uuid: 'uuid-123-abc')

      expect(result).to eq(plaintext)
    end

    it 'uses the single region ciphertext if the multi-region ciphertext is nil' do
      test_ciphertext_pair = Encryption::RegionalCiphertextPair.new(
        single_region_ciphertext: subject.encrypt(
          'single-region-text', user_uuid: '123abc'
        ).single_region_ciphertext,
        multi_region_ciphertext: nil,
      )

      result = subject.decrypt(test_ciphertext_pair, user_uuid: '123abc')

      expect(result).to eq('single-region-text')
    end
  end
end
