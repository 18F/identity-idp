require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Requests::PhoneFinderRequest do
  let(:dob) { '1980-01-01' }
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '01/01/1980',
      phone: '5551231234',
      uuid_prefix: 'ABCD',
      uuid: 'ABCD-1234-5678-9012',
    }
  end

  let(:response_body) { LexisNexisFixtures.ddp_phone_finder_success_response_json }
  subject do
    described_class.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  describe '#body' do
    context 'Idv verification request' do
      it 'returns a properly formed request body' do
        response_json = JSON.parse(subject.body)
        expected_json = JSON.parse(LexisNexisFixtures.ddp_phone_finder_request_json)
        expect(response_json).to eq(expected_json)
      end

      context 'without a dob' do
        let(:applicant) do
          hash = super()
          hash.delete(:dob)
          hash
        end

        it 'sets account_date_of_birth to an empty string' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:account_date_of_birth]).to eq('')
        end
      end

      context 'without a uuid_prefix' do
        let(:applicant) do
          hash = super()
          hash.delete(:uuid_prefix)
          hash
        end

        it 'sets local_attrib_1 to an empty string' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:local_attrib_1]).to eq('')
        end
      end

      it 'sets event_type to ACCOUNT_CREATION' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body[:event_type]).to eq('ACCOUNT_CREATION')
      end
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
