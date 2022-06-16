require 'rails_helper'

describe KeyRotator::AttributeEncryption do
  describe '#rotate' do
    let(:rotator) { described_class.new(user) }
    let(:user) { create(:user) }

    it 're-encrypts email and phone' do
      old_encrypted_email = user.encrypted_email

      rotate_attribute_encryption_key
      rotator.rotate

      expect(user.encrypted_email).to_not eq old_encrypted_email
    end

    it 'does not change the `updated_at` timestamp' do
      old_updated_timestamp = user.updated_at

      rotate_attribute_encryption_key
      rotator.rotate

      expect(user.updated_at).to eq old_updated_timestamp
    end
  end
end
