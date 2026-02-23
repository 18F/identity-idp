require 'rails_helper'

RSpec.describe Pii::UspsApplicant do
  describe '.from_idv_applicant' do
    let(:idv_applicant) do
      {
        'first_name' => Faker::Name.first_name,
        'last_name' => Faker::Name.last_name,
        'identity_doc_address1' => Faker::Address.street_address,
        'identity_doc_address2' => Faker::Address.secondary_address,
        'identity_doc_city' => Faker::Address.city,
        'identity_doc_address_state' => Faker::Address.state_abbr,
        'identity_doc_zipcode' => Faker::Address.zip_code,
        'state_id_number' => Faker::Number.number(digits: 9),
        'state_id_expiration' => Faker::Date.in_date_period(year: 2030).strftime('%Y-%m-%d'),
        'same_address_as_id' => false,
      }
    end

    it 'returns an instance Pii::UspsApplicant' do
      expect(Pii::UspsApplicant.from_idv_applicant(idv_applicant)).to have_attributes(
        first_name: idv_applicant['first_name'],
        last_name: idv_applicant['last_name'],
        address1: idv_applicant['identity_doc_address1'],
        address2: idv_applicant['identity_doc_address2'],
        city: idv_applicant['identity_doc_city'],
        state: idv_applicant['identity_doc_address_state'],
        zipcode: idv_applicant['identity_doc_zipcode'],
        id_number: idv_applicant['state_id_number'],
        id_expiration: idv_applicant['state_id_expiration'],
        current_address_same_as_id: idv_applicant['same_address_as_id'],
      )
    end
  end

  describe '#address_line2_present?' do
    context 'when address2 is not an empty string' do
      subject { Pii::UspsApplicant.new(address2: Faker::Address.secondary_address) }

      it 'returns true' do
        expect(subject.address_line2_present?).to be(true)
      end
    end

    context 'when address2 is an empty string' do
      subject { Pii::UspsApplicant.new(address2: '') }

      it 'returns false' do
        expect(subject.address_line2_present?).to be(false)
      end
    end

    context 'when address2 is nil' do
      subject { Pii::UspsApplicant.new(address2: nil) }

      it 'returns false' do
        expect(subject.address_line2_present?).to be(false)
      end
    end
  end
end
