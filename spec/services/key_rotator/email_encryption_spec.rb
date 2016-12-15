require 'rails_helper'

describe KeyRotator::EmailEncryption do
  describe '#rotate' do
    it 're-encrypts email' do
      rotator = described_class.new
      user = create(:user)
      old_encrypted_email = user.encrypted_email

      old_email_key = Figaro.env.email_encryption_key
      allow(Figaro.env).to receive(:email_encryption_key_queue).and_return("[\"#{old_email_key}\"]")
      allow(Figaro.env).to receive(:email_encryption_key).and_return('a-new-key')

      rotator.rotate(user)

      expect(user.encrypted_email).to_not eq old_encrypted_email
    end
  end
end
