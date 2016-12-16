require 'rails_helper'

describe EncryptedEmail do
  let(:email) { 'someone@example.com' }
  let(:fingerprint) { Pii::Fingerprinter.fingerprint(email) }
  let(:encrypted_email) do
    encryptor = Pii::PasswordEncryptor.new
    encryptor.encrypt(email, EncryptedEmail.new_user_access_key)
  end

  describe '#new' do
    it 'automatically decrypts' do
      ee = EncryptedEmail.new(encrypted_email)

      expect(ee.decrypted).to eq email
      expect(ee.encrypted).to eq encrypted_email
      expect(ee.fingerprint).to eq fingerprint
    end

    it 'automatically decrypts using old key' do
      encrypted_with_old_key = encrypted_email
      rotate_email_encryption_key

      expect(EncryptedEmail.new(encrypted_with_old_key).decrypted).to eq email
    end
  end

  describe '#new_from_email' do
    it 'automatically encrypts' do
      ee = EncryptedEmail.new_from_email(email)

      expect(ee.decrypted).to eq email

      ee2 = EncryptedEmail.new(ee.encrypted)

      expect(ee2.encrypted).to eq ee.encrypted
      expect(ee2.decrypted).to eq ee.decrypted
    end
  end

  describe '#stale?' do
    it 'returns true when email was encrypted with old key' do
      encrypted_with_old_key = encrypted_email
      rotate_email_encryption_key

      expect(EncryptedEmail.new(encrypted_with_old_key).stale?).to eq true
    end

    it 'returns false when email was encrypted with current key' do
      ee = EncryptedEmail.new(encrypted_email)

      expect(ee.stale?).to eq false
    end
  end
end
