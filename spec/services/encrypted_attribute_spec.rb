require 'rails_helper'

describe EncryptedAttribute do
  let(:email) { 'someone@example.com' }
  let(:fingerprint) { Pii::Fingerprinter.fingerprint(email) }
  let(:encrypted_email) do
    encryptor = Encryption::Encryptors::AttributeEncryptor.new
    encryptor.encrypt(email)
  end

  describe '#new' do
    it 'automatically decrypts' do
      ee = EncryptedAttribute.new(encrypted_email)

      expect(ee.decrypted).to eq email
      expect(ee.encrypted).to eq encrypted_email
      expect(ee.fingerprint).to eq fingerprint
    end

    it 'automatically decrypts using old key' do
      encrypted_with_old_key = encrypted_email
      rotate_attribute_encryption_key

      expect(EncryptedAttribute.new(encrypted_with_old_key).decrypted).to eq email
    end

    it 'raises an error if unable to decrypt with any keys' do
      encrypted_with_old_key = encrypted_email
      rotate_attribute_encryption_key_with_invalid_queue

      expect { EncryptedAttribute.new(encrypted_with_old_key) }.
        to raise_error Pii::EncryptionError, 'unable to decrypt attribute with any key'
    end
  end

  describe '#new_from_decrypted' do
    it 'automatically encrypts' do
      ee = EncryptedAttribute.new_from_decrypted(email)

      expect(ee.decrypted).to eq email

      ee2 = EncryptedAttribute.new(ee.encrypted)

      expect(ee2.encrypted).to eq ee.encrypted
      expect(ee2.decrypted).to eq ee.decrypted
    end
  end

  describe '#stale?' do
    it 'returns true when email was encrypted with old key' do
      encrypted_with_old_key = encrypted_email
      rotate_attribute_encryption_key

      expect(EncryptedAttribute.new(encrypted_with_old_key).stale?).to eq true
    end

    it 'returns false when email was encrypted with current key' do
      ee = EncryptedAttribute.new(encrypted_email)

      expect(ee.stale?).to eq false
    end
  end
end
