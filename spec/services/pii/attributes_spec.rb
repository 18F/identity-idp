require 'rails_helper'

RSpec.describe Pii::Attributes do
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

    it 'ignores unknown keys' do
      pii = described_class.new_from_hash(
        first_name: 'Test',
        some_unknown_field: 'unknown',
      )

      expect(pii.first_name).to eq('Test')
    end

    it 'parses state ID address keys' do
      pii = described_class.new_from_hash(
        identity_doc_address1: '1600 Pennsylvania Avenue',
        identity_doc_address2: 'Apt 2',
        identity_doc_city: 'Washington',
        state_id_jurisdiction: 'DC',
        identity_doc_zipcode: '20005',
        identity_doc_address_state: 'NY',
      )

      expect(pii.identity_doc_address1).to eq('1600 Pennsylvania Avenue')
      expect(pii.identity_doc_address2).to eq('Apt 2')
      expect(pii.identity_doc_city).to eq('Washington')
      expect(pii.state_id_jurisdiction).to eq('DC')
      expect(pii.identity_doc_zipcode).to eq('20005')
      expect(pii.identity_doc_address_state).to eq('NY')
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
