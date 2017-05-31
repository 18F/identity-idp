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

    it 'does not change the `updated_at` timestamp' do
      user = create(:user)
      old_updated_timestamp = user.updated_at

      rotate_attribute_encryption_key
      rotator = described_class.new(user)
      rotator.rotate

      expect(user.updated_at).to eq old_updated_timestamp
    end
  end
end
