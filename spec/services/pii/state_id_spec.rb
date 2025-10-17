require 'rails_helper'

RSpec.describe Pii::StateId do
  let(:state_id) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      middle_name: Faker::Name.middle_name,
      name_suffix: Faker::Name.suffix,
      address1: Faker::Address.street_name,
      address2: Faker::Address.secondary_address,
      city: Faker::Address.city,
      state: Faker::Address.state_abbr,
      zipcode: Faker::Address.zip_code,
      dob: Faker::Date.between(from: 90.years.ago, to: 13.years.ago).strftime('%Y-%m-%d'),
      sex: Faker::Gender.short_binary_type,
      height: 72,
      weight: nil,
      eye_color: Faker::Color.name,
      state_id_expiration: Faker::Date.between(from: 1.day.after, to: 2.years.after)
        .strftime('%Y-%m-%d'),
      state_id_issued: Faker::Date.between(from: 3.years.ago, to: 1.year.ago).strftime('%Y-%m-%d'),
      state_id_jurisdiction: Faker::Address.state_abbr,
      state_id_number: Faker::Number.number(digits: 9),
      document_type_received: 'state_id',
      issuing_country_code: 'USA',
    }
  end

  subject { described_class.new(**state_id) }

  describe '#id_doc_type' do
    it 'returns the value of document_type_received' do
      expect(subject.id_doc_type).to eq(state_id[:document_type_received])
    end
  end

  describe '#residential_address_required?' do
    context 'when the state is Puerto Rico' do
      subject { described_class.new(**state_id, state: 'PR') }

      it 'returns true' do
        expect(subject.residential_address_required?).to be(true)
      end
    end

    context 'when the state is not Puerto Rico' do
      subject { described_class.new(**state_id, state: 'MD') }

      it 'returns false' do
        expect(subject.residential_address_required?).to be(false)
      end
    end
  end

  describe '#to_pii_address' do
    it 'returns an Pii::Address using document address info' do
      expect(subject.to_pii_address).to have_attributes(
        address1: state_id[:address1],
        address2: state_id[:address2],
        city: state_id[:city],
        state: state_id[:state],
        zipcode: state_id[:zipcode],
      )
    end
  end
end
