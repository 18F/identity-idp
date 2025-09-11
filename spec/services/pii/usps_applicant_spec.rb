require 'rails_helper'

RSpec.describe Pii::UspsApplicant do
  describe '.from_pii' do
    let(:pii) do
      {
        'first_name' => Faker::Name.first_name,
        'last_name' => Faker::Name.last_name,
        'identity_doc_address1' => Faker::Address.street_address,
        'identity_doc_address2' => Faker::Address.secondary_address,
        'identity_doc_city' => Faker::Address.city,
        'identity_doc_address_state' => Faker::Address.state_abbr,
        'identity_doc_zipcode' => Faker::Address.zip_code,
        'state_id_number' => Faker::Number.number(digits: 9),
        'state_id_expiration_date' => Faker::Date.in_date_period(year: 2030).strftime('%Y-%m-%d'),
        'same_address_as_id' => false,
      }
    end

    it 'returns an instance Pii::UspsApplicant' do
      expect(described_class.from_pii(pii)).to have_attributes(
        first_name: pii['first_name'],
        last_name: pii['last_name'],
        address1: pii['identity_doc_address1'],
        address2: pii['identity_doc_address2'],
        city: pii['identity_doc_city'],
        state: pii['identity_doc_address_state'],
        zipcode: pii['identity_doc_zipcode'],
        id_expiration_date: pii['state_id_expiration_date'],
        id_number: pii['state_id_number'],
        current_address_same_as_id: pii['same_address_as_id'],
      )
    end
  end

  describe '#secondary_address_present?' do
    context 'when address2 is not an empty string' do
      subject { described_class.new(address2: Faker::Address.secondary_address) }

      it 'returns true' do
        expect(subject.secondary_address_present?).to be(true)
      end
    end

    context 'when address2 is an empty string' do
      subject { described_class.new(address2: '') }

      it 'returns false' do
        expect(subject.secondary_address_present?).to be(false)
      end
    end

    context 'when address2 is nil' do
      subject { described_class.new(address2: nil) }

      it 'returns false' do
        expect(subject.secondary_address_present?).to be(false)
      end
    end
  end
end
