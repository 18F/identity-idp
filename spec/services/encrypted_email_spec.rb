require 'rails_helper'

describe EncryptedEmail do
  let(:email) { 'someone@example.com' }
  let(:fingerprint) { Pii::Fingerprinter.fingerprint(email) }
  let(:encrypted_email) do
    encryptor = Pii::PasswordEncryptor.new
    encryptor.encrypt(email, EncryptedEmail.user_access_key)
  end

  describe '#new' do
    it 'automatically decrypts' do
      ee = EncryptedEmail.new(encrypted_email)

      expect(ee.decrypted).to eq email
      expect(ee.encrypted).to eq encrypted_email
      expect(ee.fingerprint).to eq fingerprint
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
end
