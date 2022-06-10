require 'rails_helper'

describe KeyRotator::AttributeEncryption do
  describe '#rotate' do
    let(:rotator) { described_class.new(email_address) }
    let(:email_address) { create(:email_address) }

    it 're-encrypts email and phone' do
      old_encrypted_email = email_address.encrypted_email

      rotate_attribute_encryption_key
      rotator.rotate

      expect(email_address.encrypted_email).to_not eq old_encrypted_email
    end

    it 'does not change the `updated_at` timestamp' do
      old_updated_timestamp = email_address.updated_at

      rotate_attribute_encryption_key
      rotator.rotate

      expect(email_address.updated_at).to eq old_updated_timestamp
    end
  end
end
