require 'rails_helper'

RSpec.describe UspsInPersonProofing::Applicant do
  let(:document_expiration_date) { Faker::Date.in_date_period(year: 2030).strftime('%Y-%m-%d') }
  let(:expiration_time_offset_hours) { 0 }
  let(:document_expiration_date_in_epoch) do
    Time.zone.parse(document_expiration_date).to_i
  end
  let(:document_type) { InPersonEnrollment::DOCUMENT_TYPE_STATE_ID }
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
  let(:applicant) { Pii::UspsApplicant.new(**applicant_pii) }
  let(:enrollment) { build('in_person_enrollment', document_type: document_type) }
  let(:email) { Faker::Internet.email(name: 'noreply') }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address)
      .and_return(email)
    allow(IdentityConfig.store).to receive(:in_person_expiration_time_offset_hours)
      .and_return(expiration_time_offset_hours)
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
      let(:document_type) { InPersonEnrollment::DOCUMENT_TYPE_STATE_ID }

      it_behaves_like 'when values contains transliterable characters'
    end

    context 'from_usps_applicant_and_enrollment w passport book' do
      let(:document_type) { InPersonEnrollment::DOCUMENT_TYPE_PASSPORT_BOOK }

      it_behaves_like 'when values contains transliterable characters'
    end

    context 'when values do not contain transliterable characters' do
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

    context 'when the applicant has a second address line' do
      let(:applicant) do
        Pii::UspsApplicant.new(
          **applicant_pii.merge(address1: '123 Main St', address2: 'Apt 4'),
        )
      end

      it 'joins both lines into the address with a space' do
        expect(
          described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ).address,
        ).to eq('123 Main St Apt 4')
      end
    end

    context 'when the second address line is blank' do
      let(:applicant) do
        Pii::UspsApplicant.new(
          **applicant_pii.merge(address1: '123 Main St', address2: ''),
        )
      end

      it 'uses only the first line with no trailing space' do
        expect(
          described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ).address,
        ).to eq('123 Main St')
      end
    end

    context 'when the combined address exceeds 255 characters' do
      let(:applicant) do
        Pii::UspsApplicant.new(
          **applicant_pii.merge(address1: 'A' * 200, address2: 'B' * 200),
        )
      end

      it 'truncates the address to 255 characters' do
        address = described_class.from_usps_applicant_and_enrollment(
          applicant,
          enrollment,
        ).address

        expect(address.length).to eq(255)
        expect(address).to eq(('A' * 200) + ' ' + ('B' * 54))
      end
    end

    context 'with a non-standard expiration value (LG-17733)' do
      ['military', 'indefinite', 'none', '9999-99-99', '0000-00-00'].each do |value|
        context "when id_expiration is #{value.inspect}" do
          let(:applicant) { Pii::UspsApplicant.new(**applicant_pii.merge(id_expiration: value)) }

          it 'does not set a document_expiration_date' do
            expect(
              described_class.from_usps_applicant_and_enrollment(
                applicant,
                enrollment,
              ).document_expiration_date,
            ).to be_nil
          end
        end
      end

      context 'when id_expiration is blank' do
        let(:applicant) { Pii::UspsApplicant.new(**applicant_pii.merge(id_expiration: nil)) }

        it 'does not set a document_expiration_date' do
          expect(
            described_class.from_usps_applicant_and_enrollment(
              applicant,
              enrollment,
            ).document_expiration_date,
          ).to be_nil
        end
      end
    end

    context 'with an offset to the expiration time', timezone: 'UTC' do
      context 'with an offset of zero' do
        it 'shows the previous date if interpreted in US timezone' do
          exp_date = described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ).document_expiration_date
          expect(
            Time.at(
              exp_date,
              in: '-07:00',
            ).strftime('%Y-%m-%d'),
          ).not_to eq document_expiration_date
        end
      end

      context 'with an offset of 23 hrs' do
        let(:expiration_time_offset_hours) { 23 }

        it 'shows the correct date if interpreted in US timezone' do
          exp_date = described_class.from_usps_applicant_and_enrollment(
            applicant,
            enrollment,
          ).document_expiration_date
          expect(
            Time.at(
              exp_date,
              in: '-07:00',
            ).strftime('%Y-%m-%d'),
          ).to eq document_expiration_date
        end
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
