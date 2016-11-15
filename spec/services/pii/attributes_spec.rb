require 'rails_helper'

describe Pii::Attributes do
  let(:user_access_key) { UserAccessKey.new('sekrit', SecureRandom.uuid) }

  describe '#new_from_hash' do
    it 'initializes from plain Hash' do
      pii = described_class.new_from_hash(first_name: 'Jane')

      expect(pii.first_name).to eq 'Jane'
    end
  end

  describe '#new_from_encrypted' do
    it 'inflates from encrypted string' do
      orig_attrs = described_class.new_from_hash(first_name: 'Jane')
      encrypted_pii = orig_attrs.encrypted(user_access_key)
      pii_attrs = described_class.new_from_encrypted(encrypted_pii, user_access_key)

      expect(pii_attrs.first_name).to eq 'Jane'
    end
  end

  describe '#new_from_json' do
    it 'inflates from JSON string' do
      pii_json = { first_name: 'Jane' }.to_json
      pii_attrs = described_class.new_from_json(pii_json)

      expect(pii_attrs.first_name).to eq 'Jane'
    end
  end

  describe '#encrypted' do
    it 'returns the object as encrypted string' do
      pii_attrs = described_class.new_from_hash(first_name: 'Jane')

      expect(pii_attrs.encrypted(user_access_key)).to_not match 'Jane'
    end
  end
end
