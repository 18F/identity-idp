require 'rails_helper'

RSpec.describe Encryption::Encryptors::EccPiiEncryptor do
  describe '#decrypt' do
    it 'can decrypt a ciphertext encrypted with the encryptor' do
      user_uuid = '123-456'
      password = 'super duper password'
      user_key = OpenSSL::PKey::EC.generate('secp384r1')
      encoded_user_public_key = Base64.strict_encode64(user_key.public_to_der)
      encrypted_user_private_key = Encryption::Encryptors::UserPrivateKeyEncryptor.new(password).encrypt(
        user_key,
        user_uuid: user_uuid,
      )

      plaintext = 'oat milk dirty chai with an extra shot'

      ciphertext = described_class.new.encrypt(
        plaintext,
        encoded_user_public_key,
      )

      result = described_class.new.decrypt(
        ciphertext,
        encrypted_user_private_key,
        password,
        user_uuid: user_uuid,
      )

      expect(result).to eq(plaintext)
    end

    it 'fails to decrypt a ciphertext when the user password is incorrect'

    it 'fails to decrypt a ciphertext when the user private key is incorrect'

    it 'fails to decrypt a ciphertext when the encrypted data is modified'
  end

  describe '#encrypt' do
    it 'encrypts a decryptable ciphertext' do
      user_key = OpenSSL::PKey::EC.generate('secp384r1')
      encoded_user_public_key = Base64.strict_encode64(user_key.public_to_der)

      plaintext = 'oat milk dirty chai with an extra shot'

      ciphertext = described_class.new.encrypt(
        plaintext,
        encoded_user_public_key,
      )

      parsed_ciphertext = JSON.parse(ciphertext)
      encrypted_data = Base64.strict_decode64(parsed_ciphertext['encrypted_data'])
      ephemeral_public_key = OpenSSL::PKey::EC.new(
        Base64.strict_decode64(
          parsed_ciphertext['ephemeral_public_key'],
        ),
      )

      expect(ephemeral_public_key.private?).to eq(false)

      shared_secret = user_key.dh_compute_key(ephemeral_public_key.public_key)
      result = Encryption::AesCipherV2.new.decrypt(encrypted_data, shared_secret)

      expect(result).to eq(plaintext)
    end
  end
end
