require 'rails_helper'

RSpec.describe UspsInPersonProofing::Applicant do
  describe '#has_valid_address?' do
    let(:applicant) do
      described_class.new(
        unique_id: Faker::Number.number(digits: 10),
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        address:,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zip_code: Faker::Address.zip_code,
        email: Faker::Internet.email,
        document_number: Faker::Number.number(digits: 9),
        document_expiration_date: Faker::Date.in_date_period(year: 2030),
        document_type: 'state_id',
      )
    end

    context 'when the address is valid' do
      let(:address) { Faker::Address.street_address }

      subject do
        applicant.has_valid_address?
      end

      it { is_expected.to eq(true) }
    end

    context 'when the address invalid' do
      let(:address) { '!@#$%' }

      subject do
        applicant.has_valid_address?
      end

      it { is_expected.to eq(false) }
    end
  end
end
