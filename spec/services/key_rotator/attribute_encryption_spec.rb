require 'rails_helper'

describe KeyRotator::AttributeEncryption do
  describe '#rotate' do
    it 're-encrypts email and phone' do
      user = create(:user, phone: '213-555-5555')
      rotator = described_class.new(user)
      old_encrypted_email = user.encrypted_email
      old_encrypted_phone = user.encrypted_phone

      rotate_attribute_encryption_key

      rotator.rotate

      expect(user.encrypted_email).to_not eq old_encrypted_email
      expect(user.encrypted_phone).to_not eq old_encrypted_phone
    end
  end
end
