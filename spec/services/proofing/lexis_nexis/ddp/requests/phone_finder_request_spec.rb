require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Requests::PhoneFinderRequest do
  let(:dob) { '1980-01-01' }
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '01/01/1980',
      phone: '5551231234',
      ssn: '123456789',
      uuid_prefix: 'ABCD',
      uuid: 'ABCD-1234-5678-9012',
    }
  end

  subject do
    described_class.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  describe '#body' do
    let(:request_body) { JSON.parse(subject.body, symbolize_names: true) }

    context 'when all applicant params are present' do
      let(:expected_body) do
        JSON.parse(LexisNexisFixtures.ddp_phone_finder_request_json, symbolize_names: true)
      end

      it 'returns a properly formed request body' do
        expect(request_body).to eq(expected_body)
      end
    end

    context 'without a dob' do
      let(:applicant) { super().reject { |key| key == :dob } }

      it 'sets account_date_of_birth to an empty string' do
        expect(request_body[:account_date_of_birth]).to eq('')
      end
    end

    context 'without an SSN' do
      let(:applicant) { super().reject { |key| key == :ssn } }

      it 'sets national_id_number to an empty string' do
        expect(request_body[:national_id_number]).to eq('')
      end

      it 'sets national_id_type to an empty string' do
        expect(request_body[:national_id_type]).to eq('')
      end
    end

    context 'with an empty string for SSN' do
      let(:applicant) { super().merge(ssn: '') }

      it 'sets national_id_number to an empty string' do
        expect(request_body[:national_id_number]).to eq('')
      end

      it 'does not set national_id_type to US_SSN' do
        expect(request_body[:national_id_type]).not_to eq('US_SSN')
      end
    end

    context 'without a uuid_prefix' do
      let(:applicant) { super().reject { |key| key == :uuid_prefix } }

      it 'sets local_attrib_1 to an empty string' do
        expect(request_body[:local_attrib_1]).to eq('')
      end
    end

    it 'sets event_type to ACCOUNT_CREATION' do
      expect(request_body[:event_type]).to eq('ACCOUNT_CREATION')
    end
  end

  describe '#url' do
    it 'returns a url for the DDP session query endpoint' do
      expect(subject.url).to eq('https://example.com/api/attribute-query')
    end
  end

  describe '#build_request_headers' do
    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_hmac_auth_enabled).and_return(true)
    end

    it 'does not include an Authorization header' do
      expect(subject.send(:build_request_headers)['Authorization']).to be_nil
    end
  end
end
