require 'rails_helper'

describe Idv::DocPiiForm do
  let(:user) { create(:user) }
  let(:subject) { Idv::DocPiiForm }
  let(:valid_dob) { (Time.zone.today - (AppConfig.env.idv_min_age.to_i + 1).years).to_s }
  let(:good_pii) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      dob: valid_dob,
      state: Faker::Address.state_abbr,
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

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns a successful form response' do
        result = subject.new(good_pii).submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when there is an error with both name fields' do
      it 'returns a single name-specific pii error' do
        result = subject.new(name_errors_pii).submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [t('doc_auth.errors.lexis_nexis.full_name_check')]
      end
    end

    context 'when there is an error with name fields and dob' do
      it 'returns a single generic pii error' do
        result = subject.new(name_and_dob_errors_pii).submit

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors[:pii]).to eq [
          t('doc_auth.errors.lexis_nexis.general_error_no_liveness'),
        ]
      end
    end
  end
end
