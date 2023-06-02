require 'rails_helper'

describe Idv::StateIdForm do
  let(:subject) { Idv::StateIdForm.new(pii) }
  let(:valid_dob) do
    valid_d = Time.zone.today - IdentityConfig.store.idv_min_age_years.years - 1.day
    ActionController::Parameters.new(
      {
        year: valid_d.year,
        month: valid_d.month,
        day: valid_d.mday,
      },
    ).permit(:year, :month, :day)
  end
  let(:too_young_dob) do
    (Time.zone.today - IdentityConfig.store.idv_min_age_years.years + 1.day).to_s
  end
  let(:good_params) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      identity_doc_address1: Faker::Address.street_address,
      identity_doc_address2: Faker::Address.secondary_address,
      identity_doc_zipcode: Faker::Address.zip_code,
      identity_doc_address_state: Faker::Address.state_abbr,
      same_address_as_id: 'true',
      state_id_jurisdiction: 'AL',
      state_id_number: Faker::IDNumber.valid,
    }
  end
  let(:dob_min_age_name_error_params) do
    {
      first_name: Faker::Name.first_name + invalid_char,
      last_name: Faker::Name.last_name,
      dob: too_young_dob,
      identity_doc_address1: Faker::Address.street_address,
      identity_doc_address2: Faker::Address.secondary_address,
      identity_doc_zipcode: Faker::Address.zip_code,
      identity_doc_address_state: Faker::Address.state_abbr,
      same_address_as_id: 'true',
      state_id_jurisdiction: 'AL',
      state_id_number: Faker::IDNumber.valid,
    }
  end
  let(:invalid_char) { '1' }
  let(:name_error_params) do
    {
      first_name: Faker::Name.first_name + invalid_char,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      identity_doc_address1: Faker::Address.street_address,
      identity_doc_address2: Faker::Address.secondary_address,
      identity_doc_zipcode: Faker::Address.zip_code,
      identity_doc_address_state: Faker::Address.state_abbr,
      same_address_as_id: 'true',
      state_id_jurisdiction: 'AL',
      state_id_number: Faker::IDNumber.valid,
    }
  end
  let(:pii) { nil }
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.submit(good_params)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when there is an error with name' do
      it 'returns a single name error when name is wrong' do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).and_return(true)
        result = subject.submit(name_error_params)
        expect(subject.errors.empty?).to be(false)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(subject.errors[:first_name]).to eq [
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: [invalid_char].join(', '),
          ),
        ]
        expect(result.errors.empty?).to be(true)
      end
      it 'returns both name and dob error when both fields are invalid' do
        allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).and_return(true)
        result = subject.submit(dob_min_age_name_error_params)
        expect(subject.errors.empty?).to be(false)
        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(subject.errors[:first_name]).to eq [
          I18n.t(
            'in_person_proofing.form.state_id.errors.unsupported_chars',
            char_list: [invalid_char].join(', '),
          ),
        ]
        expect(subject.errors[:dob]).to eq [
          I18n.t(
            'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
            app_name: APP_NAME,
          ),
        ]
      end
    end
  end
end
