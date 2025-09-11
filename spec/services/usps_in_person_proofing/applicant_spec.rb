require 'rails_helper'

RSpec.describe UspsInPersonProofing::Applicant do
  let(:applicant_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      address1: Faker::Address.street_name,
      city: Faker::Address.city,
      state: Faker::Address.state_abbr,
      zipcode: Faker::Address.zip_code,
      id_number: Faker::Number.number(digits: 9),
      id_expiration: Faker::Date.in_date_period(year: 2030).strftime('%Y-%m-%d'),
    }
  end

  describe '.from_usps_applicant_and_enrollment' do
    context 'when values contains transliterable characters' do
      let(:applicant) do
        Pii::UspsApplicant.new(
          **applicant_pii.merge(
            first_name: 'Tèst',
            last_name: 'Tèstington',
            address1: 'Qüery ST',
            city: 'Qüertyton',
          ),
        )
      end
      let(:enrollment) { build('in_person_enrollment', document_type: 'state_id') }
      let(:email) { Faker::Internet.email(name: 'noreply') }

      before do
        allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address)
          .and_return(email)
      end

      it 'returns a UspsInPersonProofing::Applicant' do
        expect(
          described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ),
        ).to have_attributes(
          unique_id: enrollment.unique_id,
          first_name: 'Test',
          last_name: 'Testington',
          address: 'Query ST',
          city: 'Quertyton',
          state: applicant.state,
          zip_code: applicant.zipcode,
          document_number: applicant.id_number,
          document_expiration_date: applicant.id_expiration,
          email:,
          document_type: enrollment.document_type,
        )
      end
    end

    context 'when values do not contain transliterable characters' do
      let(:applicant) { Pii::UspsApplicant.new(**applicant_pii) }
      let(:enrollment) { build('in_person_enrollment', document_type: 'state_id') }
      let(:email) { Faker::Internet.email(name: 'noreply') }

      before do
        allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address)
          .and_return(email)
      end

      it 'returns a UspsInPersonProofing::Applicant' do
        expect(
          described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ),
        ).to have_attributes(
          unique_id: enrollment.unique_id,
          first_name: applicant.first_name,
          last_name: applicant.last_name,
          address: applicant.address1,
          city: applicant.city,
          state: applicant.state,
          zip_code: applicant.zipcode,
          document_number: applicant.id_number,
          document_expiration_date: applicant.id_expiration,
          email:,
          document_type: enrollment.document_type,
        )
      end
    end
  end

  describe '#has_valid_address?' do
    let(:applicant) { described_class.new(address:) }

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
