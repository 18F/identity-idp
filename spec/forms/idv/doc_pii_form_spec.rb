require 'rails_helper'

describe Idv::DocPiiForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::DocPiiForm.new(pii: pii) }
  let(:valid_dob) { (Time.zone.today - (IdentityConfig.store.idv_min_age_years + 1).years).to_s }
  let(:too_young_dob) do
    (Time.zone.today - (IdentityConfig.store.idv_min_age_years - 1).years).to_s
  end
  let(:good_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'AL',
    }
  end
  let(:name_errors_pii) do
    { first_name: nil, last_name: nil, dob: valid_dob,
      state: Faker::Address.state_abbr }
  end
  let(:name_and_dob_errors_pii) do
    { first_name: nil, last_name: nil, dob: nil,
      state: Faker::Address.state_abbr }
  end
  let(:dob_min_age_error_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: too_young_dob,
      state: Faker::Address.state_abbr,
    }
  end
  let(:non_string_zipcode_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      state: Faker::Address.state_abbr,
      zipcode: 12345,
      state_id_jurisdiction: 'AL',
    }
  end
  let(:jurisdiction_error_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      zipcode: Faker::Address.zip_code,
      state: Faker::Address.state_abbr,
      state_id_jurisdiction: 'XX',
    }
  end
  let(:pii) { nil }

  describe '#submit' do
    context 'when the form is valid' do
      let(:pii) { good_pii }

      it 'returns a successful form response' do
        result = subject.submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra).to eq(
          attention_with_barcode: false,
          pii_like_keypaths: [[:pii]],
        )
      end
    end

    context 'when there is an error with both name fields' do
      let(:pii) { name_errors_pii }

      it 'returns a single name-specific pii error' do
        result = subject.submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [t('doc_auth.errors.alerts.full_name_check')]
        expect(result.extra).to eq(
          attention_with_barcode: false,
          pii_like_keypaths: [[:pii]],
        )
      end
    end

    context 'when there is an error with name fields and dob' do
      let(:pii) { name_and_dob_errors_pii }

      it 'returns a single generic pii error' do
        result = subject.submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [
          t('doc_auth.errors.general.no_liveness'),
        ]
        expect(result.extra).to eq(
          attention_with_barcode: false,
          pii_like_keypaths: [[:pii]],
        )
      end
    end

    context 'when there is an error with dob minimum age' do
      let(:pii) { dob_min_age_error_pii }

      it 'returns a single min age error' do
        result = subject.submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [
          t('doc_auth.errors.pii.birth_date_min_age'),
        ]
        expect(result.extra).to eq(
          attention_with_barcode: false,
          pii_like_keypaths: [[:pii]],
        )
      end
    end

    context 'when there is a non-string zipcode' do
      let(:pii) { non_string_zipcode_pii }

      it 'returns a single generic pii error' do
        result = subject.submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [
          t('doc_auth.errors.general.no_liveness'),
        ]
        expect(result.extra).to eq(
          attention_with_barcode: false,
          pii_like_keypaths: [[:pii]],
        )
      end
    end

    context 'when there was attention with barcode' do
      let(:subject) { Idv::DocPiiForm.new(pii: good_pii, attention_with_barcode: true) }

      it 'adds value as extra attribute' do
        result = subject.submit

        expect(result.extra[:attention_with_barcode]).to eq(true)
      end
    end
  end

  context 'when there is an invalid jurisdiction' do
    let(:subject) { Idv::DocPiiForm.new(pii: jurisdiction_error_pii) }

    it 'responds with an unsuccessful result' do
      result = subject.submit

      expect(result.success?).to eq(false)
    end
  end
end
