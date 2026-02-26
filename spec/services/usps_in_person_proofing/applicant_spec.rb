require 'rails_helper'

RSpec.describe UspsInPersonProofing::Applicant do
  let(:document_expiration_date) { Faker::Date.in_date_period(year: 2030).strftime('%Y-%m-%d') }
  let(:document_expiration_date_in_epoch) do
    ActiveSupport::TimeZone['UTC'].parse(document_expiration_date).to_i
  end
  let(:document_type) { Idp::Constants::DocumentTypes::STATE_ID }
  let(:usps_expected_document_type) do
    UspsInPersonProofing::USPS_DOCUMENT_TYPE_MAPPINGS[document_type]
  end
  let(:applicant_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      address1: Faker::Address.street_name,
      city: Faker::Address.city,
      state: Faker::Address.state_abbr,
      zipcode: Faker::Address.zip_code,
      id_number: Faker::Number.number(digits: 9),
      id_expiration: document_expiration_date,
    }
  end

  describe '.from_usps_applicant_and_enrollment' do
    shared_examples 'when values contains transliterable characters' do
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
      let(:enrollment) { build('in_person_enrollment', document_type: document_type) }
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
          document_expiration_date: document_expiration_date_in_epoch,
          email:,
          document_type: usps_expected_document_type,
        )
      end
    end

    context 'from_usps_applicant_and_enrollment w state_id' do
      let(:document_type) { Idp::Constants::DocumentTypes::STATE_ID }

      it_behaves_like 'when values contains transliterable characters'
    end

    context 'from_usps_applicant_and_enrollment w passport book' do
      let(:document_type) { Idp::Constants::DocumentTypes::PASSPORT_BOOK }

      it_behaves_like 'when values contains transliterable characters'
    end

    context 'when values do not contain transliterable characters' do
      let(:applicant) { Pii::UspsApplicant.new(**applicant_pii) }
      let(:enrollment) { build('in_person_enrollment', document_type: document_type) }
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
          document_expiration_date: document_expiration_date_in_epoch,
          email:,
          document_type: usps_expected_document_type,
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
