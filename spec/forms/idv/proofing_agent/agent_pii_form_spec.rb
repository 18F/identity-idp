require 'rails_helper'

RSpec.describe Idv::ProofingAgent::AgentPiiForm do
  let(:valid_dob) { (Time.zone.today - (IdentityConfig.store.idv_min_age_years + 1).years).to_s }
  let(:too_young_dob) do
    (Time.zone.today - (IdentityConfig.store.idv_min_age_years - 1).years).to_s
  end

  let(:valid_address) do
    {
      address1: '1 Main St',
      address2: 'Apt 2',
      city: 'Anytown',
      state: 'CA',
      zip_code: '94110',
    }
  end

  let(:valid_state_id) do
    {
      document_number: 'D1234567',
      jurisdiction: 'CA',
      expiration_date: (Time.zone.today + 365).to_s,
      issue_date: '2020-01-01',
      address1: '1 Main St',
      address2: 'Apt 2',
      city: 'Anytown',
      state: 'CA',
      zip_code: '94110',
    }
  end

  let(:valid_passport) do
    {
      expiration_date: (Time.zone.today + 365).to_s,
      issue_date: '2020-01-01',
      mrz: 'P<UTOSAMPLE<<COMPANY<<<<<<<<<<<<<<<<<<<<<<<<' \
           'ACU1234P<5UTO0003067F4003065<<<<<<<<<<<<<<02',
      issuing_country_code: 'USA',
    }
  end

  let(:state_id_pii) do
    {
      first_name: 'Jane',
      last_name: 'Doe',
      dob: valid_dob,
      email: 'jane@example.com',
      phone: '5555551212',
      ssn: '123456789',
      id_type: 'drivers_license',
      state_id: valid_state_id,
    }
  end

  let(:passport_pii) do
    {
      first_name: 'Jane',
      last_name: 'Doe',
      dob: valid_dob,
      email: 'jane@example.com',
      phone: '5555551212',
      ssn: '123456789',
      id_type: 'passport',
      passport: valid_passport,
      residential_address: valid_address,
    }
  end

  subject(:form) { described_class.new(pii: pii) }

  before do
    allow(FeatureManagement).to receive(:idv_proofing_agent_passport_enabled?)
      .and_return(true)
  end

  describe '#submit' do
    context 'with a valid state_id payload' do
      let(:pii) { state_id_pii }

      it 'returns a successful form response' do
        result = form.submit
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra[:document_type_received]).to eq('drivers_license')
      end
    end

    context 'with a valid passport payload' do
      let(:pii) { passport_pii }

      it 'returns a successful form response' do
        result = form.submit
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
        expect(result.extra[:document_type_received]).to eq('passport')
      end
    end

    context 'with missing required top-level fields' do
      let(:pii) { state_id_pii.merge(first_name: nil, ssn: nil) }

      it 'reports cannot-be-blank with the original key names' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:first_name]).to include('cannot be blank')
        expect(result.errors[:ssn]).to include('cannot be blank')
      end
    end

    context 'with an under-age dob' do
      let(:pii) { state_id_pii.merge(dob: too_young_dob) }

      it 'reports a dob_min_age error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:dob_min_age])
          .to include('age does not meet minimum requirements')
      end
    end

    context 'when both state_id and passport are present' do
      let(:pii) { state_id_pii.merge(passport: valid_passport) }

      it 'reports a state_id_and_passport error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to include('cannot include both state_id and passport')
      end
    end

    context 'when neither state_id nor passport is present' do
      let(:pii) { state_id_pii.merge(state_id: nil) }

      it 'reports a state_id_or_passport_blank error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:base]).to include('either state_id or passport must be present')
      end
    end

    context 'when passport is present but residential_address is missing' do
      let(:pii) { passport_pii.merge(residential_address: nil) }

      it 'reports the residential_address error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:residential_address])
          .to include('residential address must be present with passport')
      end
    end

    context 'with an invalid state_id zip_code' do
      let(:pii) { state_id_pii.merge(state_id: valid_state_id.merge(zip_code: 'abc')) }

      it 'surfaces the error under the original (zip_code) key' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:zip_code]).to be_present
      end
    end

    context 'with an unsupported state_id jurisdiction' do
      let(:pii) { state_id_pii.merge(state_id: valid_state_id.merge(jurisdiction: 'ZZ')) }

      it 'reports the jurisdiction error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:jurisdiction]).to include('is not a valid state code')
      end
    end

    context 'with an id_type that does not match the data shape' do
      let(:pii) { state_id_pii.merge(id_type: 'passport', state_id: valid_state_id) }

      it 'reports a passport_type mismatch' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:passport_type]).to include('mis-matched type vs data')
      end
    end

    context 'with an unsupported id_type' do
      let(:pii) { state_id_pii.merge(id_type: 'library_card') }

      it 'reports an unknown_id_type error' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:unknown_id_type]).to include('unsupported id_type')
      end
    end

    context 'with USPS-strict residential address violations' do
      let(:pii) do
        passport_pii.merge(
          residential_address: valid_address.merge(city: 'Bad$City', address1: '1 Main St!'),
        )
      end

      it 'reports transliterable errors on the residential address' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:city].join).to match(/has invalid characters/)
        expect(result.errors[:address1].join).to match(/has invalid characters/)
      end
    end

    context 'with USPS-strict state_id address violations' do
      let(:pii) do
        state_id_pii.merge(
          state_id: valid_state_id.merge(city: 'Bad$City', address1: '1 Main St!'),
        )
      end

      it 'reports transliterable errors on the state_id address' do
        result = form.submit
        expect(result.success?).to eq(false)
        expect(result.errors[:city].join).to match(/has invalid characters/)
        expect(result.errors[:address1].join).to match(/has invalid characters/)
      end
    end
  end

  describe 'field rules' do
    def submit_with(**overrides)
      described_class.new(pii: state_id_pii.merge(overrides)).submit
    end

    it 'accepts values at the max length' do
      result = submit_with(first_name: 'a' * 128, last_name: 'a' * 128, phone: '1' * 20)
      expect(result.success?).to eq(true)
    end

    it 'reports values over the max length' do
      result = submit_with(first_name: 'a' * 129, email: "#{'a' * 244}@example.com")
      expect(result.success?).to eq(false)
      expect(result.errors[:first_name]).to eq(['is too long (maximum is 128 characters)'])
      expect(result.errors[:email]).to eq(['is too long (maximum is 255 characters)'])
    end

    it 'reports non-string values' do
      expect(submit_with(phone: 5555551212).errors[:phone]).to eq(['must be a string'])
    end

    it 'reports an ssn that contains dashes' do
      expect(submit_with(ssn: '123-45-6789').errors[:ssn]).to eq(
        ['is too long (maximum is 9 characters)', 'must contain only digits'],
      )
    end

    context 'with an invalid dob' do
      %w[04-04-1990 1990-02-30 19900404].each do |bad_dob|
        it "reports a format error for #{bad_dob} without checking minimum age" do
          result = submit_with(dob: bad_dob)
          expect(result.errors[:dob]).to include('must be in YYYY-MM-DD format')
          expect(result.errors[:dob_min_age]).to be_blank
        end
      end

      it 'reports a non-string dob without raising' do
        expect(submit_with(dob: 19900404).errors[:dob]).to eq(['must be a string'])
      end
    end

    it 'reports nested state_id violations under the nested key' do
      result = submit_with(
        state_id: valid_state_id.merge(document_number: '1' * 65, issue_date: '2020/01/01'),
      )
      expect(result.errors[:'state_id.document_number'])
        .to eq(['is too long (maximum is 64 characters)'])
      expect(result.errors[:'state_id.issue_date']).to eq(['must be in YYYY-MM-DD format'])
    end

    it 'reports nested residential_address violations under the nested key' do
      result = submit_with(residential_address: valid_address.merge(state: 'a' * 65))
      expect(result.errors[:'residential_address.state'])
        .to eq(['is too long (maximum is 64 characters)'])
    end

    it 'skips blank optional fields' do
      result = submit_with(
        state_id: valid_state_id.merge(issue_date: nil, expiration_date: '', address2: nil),
      )
      expect(result.success?).to eq(true)
    end
  end

  describe '.pii_like_keypaths' do
    it 'returns state_id-shaped keypaths for non-passport document types' do
      keypaths = described_class.pii_like_keypaths(document_type: 'drivers_license')
      expect(keypaths).to include([:errors, :document_number])
      expect(keypaths).to include([:errors, :zip_code])
    end

    it 'returns passport-shaped keypaths for passport document types' do
      keypaths = described_class.pii_like_keypaths(document_type: 'passport')
      expect(keypaths).to include([:errors, :mrz])
      expect(keypaths).to include([:errors, :issuing_country_code])
    end
  end
end
