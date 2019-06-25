require 'rails_helper'

describe Pii::Attributes do
  let(:password) { 'I am the password' }

  describe '#new_from_hash' do
    it 'initializes from plain Hash' do
      pii = described_class.new_from_hash(first_name: 'Jane')

      expect(pii.first_name).to eq 'Jane'
    end

    it 'initializes from complex Hash' do
      pii = described_class.new_from_hash(
        first_name: 'José',
        last_name: 'Foo',
      )

      expect(pii.first_name.to_s).to eq 'José'
      expect(pii.first_name).to be_a String
      expect(pii.last_name).to be_a String
    end

    it 'assigns to all members' do
      pii = described_class.new_from_hash(first_name: 'Jane')

      expect(pii.last_name).to eq nil
    end
  end

  describe '#new_from_json' do
    it 'inflates from JSON string' do
      pii_json = { first_name: 'Jane' }.to_json
      pii_attrs = described_class.new_from_json(pii_json)

      expect(pii_attrs.first_name.to_s).to eq 'Jane'
    end

    it 'returns all-nil object when passed blank JSON' do
      expect(described_class.new_from_json(nil)).to be_a Pii::Attributes
      expect(described_class.new_from_json('')).to be_a Pii::Attributes
    end
  end

  describe '#==' do
    it 'treats objects with same values as equal' do
      pii_one = described_class.new_from_hash(first_name: 'Jane')
      pii_two = described_class.new_from_hash(first_name: 'Jane')

      expect(pii_one).to eq pii_two
    end
  end
end
