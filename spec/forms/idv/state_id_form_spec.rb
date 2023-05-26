require 'rails_helper'

describe Idv::StateIdForm do
  let(:subject) { Idv::StateIdForm.new(pii) }
  let(:valid_dob) do
    valid_d = (Time.zone.today - (IdentityConfig.store.idv_min_age_years + 1).years).to_s.split('-')

    ActionController::Parameters.new(
      {
        year: valid_d[0],
        month: valid_d[1],
        day: valid_d[2],
      },
    ).permit(:year, :month, :day)
  end
  let(:too_young_dob) do
    (Time.zone.today - (IdentityConfig.store.idv_min_age_years - 1).years).to_s
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
  let(:dob_min_age_error_params) do
    {
      first_name: Faker::Name.first_name,
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

    context 'when there is an error with dob minimum age' do
      it 'returns a single min age error' do
        result = subject.submit(dob_min_age_error_params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:dob]).to eq [I18n.t('doc_auth.errors.pii.birth_date_min_age')]
      end
    end
  end
end
