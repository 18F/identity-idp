require 'rails_helper'

RSpec.describe Pii::Passport do
  let(:passport) do
    {
      first_name: Faker::Name.first_name,
      middle_name: Faker::Name.middle_name,
      last_name: Faker::Name.last_name,
      dob: Faker::Date.between(from: 90.years.ago, to: 13.years.ago).strftime('%Y-%m-%d'),
      sex: Faker::Gender.short_binary_type,
      birth_place: Faker::Address.city,
      passport_expiration: Faker::Date.between(from: 1.day.after, to: 2.years.after)
        .strftime('%Y-%m-%d'),
      issuing_country_code: 'USA',
      mrz: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PASSPORT[:mrz],
      passport_issued: Faker::Date.between(from: 3.years.ago, to: 1.year.ago).strftime('%Y-%m-%d'),
      nationality_code: 'USA',
      document_number: Faker::Number.number(digits: 9),
      document_type_received: 'passport',
    }
  end

  subject { Pii::Passport.new(**passport) }

  describe '#id_doc_type' do
    it 'returns the value of document_type_received' do
      expect(subject.id_doc_type).to eq(passport[:document_type_received])
    end
  end

  describe '#residential_address_required?' do
    it 'returns true' do
      expect(subject.residential_address_required?).to be(true)
    end
  end

  describe '#to_pii_address' do
    it 'returns an empty Pii::Address' do
      expect(subject.to_pii_address).to have_attributes(
        address1: nil,
        address2: nil,
        city: nil,
        state: nil,
        zipcode: nil,
      )
    end
  end
end
