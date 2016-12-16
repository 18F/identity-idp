require 'rails_helper'

describe KeyRotator::EmailEncryption do
  describe '#rotate' do
    it 're-encrypts email' do
      rotator = described_class.new
      user = create(:user)
      old_encrypted_email = user.encrypted_email

      rotate_email_encryption_key

      rotator.rotate(user)

      expect(user.encrypted_email).to_not eq old_encrypted_email
    end
  end
end
