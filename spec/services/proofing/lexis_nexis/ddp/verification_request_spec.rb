require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::VerificationRequest do
  let(:dob) { '1980-01-01' }
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123-45-6789',
      dob: dob,
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '12345678',
      state_id_jurisdiction: 'LA',
      phone: '5551231234',
      threatmetrix_session_id: 'UNIQUE_SESSION_ID',
      email: 'test@example.com',
      request_ip: '127.0.0.1',
      uuid_prefix: 'ABCD',
    }
  end

  let(:response_body) { LexisNexisFixtures.ddp_success_response_json }
  subject do
    described_class.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_policy).
      and_return('test-policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_authentication_policy).
      and_return('test-authentication-policy')
  end

  describe '#body' do
    context 'Idv verification request' do
      it 'returns a properly formed request body' do
        response_json = JSON.parse(subject.body)
        expected_json = JSON.parse(LexisNexisFixtures.ddp_request_json)
        expect(response_json).to eq(expected_json)
      end

      context 'without an address line 2' do
        let(:applicant) do
          hash = super()
          hash.delete(:address2)
          hash
        end

        it 'sets StreetAddress2 to and empty string' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:account_address_street2]).to eq('')
        end
      end
    end

    context 'Authentication verification request' do
      let(:applicant) do
        {
          threatmetrix_session_id: 'UNIQUE_SESSION_ID',
          email: 'test@example.com',
          request_ip: '127.0.0.1',
        }
      end

      subject do
        described_class.new(
          applicant: applicant,
          config: LexisNexisFixtures.example_ddp_authentication_config,
        )
      end

      it 'returns a properly formed request body' do
        response_json = JSON.parse(subject.body)
        expected_json = JSON.parse(LexisNexisFixtures.ddp_authentication_request_json)
        expect(response_json).to eq(expected_json)
      end

      context 'with service provider associated with user' do
        let(:applicant) do
          {
            threatmetrix_session_id: 'UNIQUE_SESSION_ID',
            email: 'test@example.com',
            request_ip: '127.0.0.1',
            uuid_prefix: 'SPNUM',
          }
        end

        it 'returns a properly formed request body' do
          response_json = JSON.parse(subject.body)

          base_json = JSON.parse(LexisNexisFixtures.ddp_authentication_request_json)
          expected_json = base_json.merge({ 'local_attrib_1' => 'SPNUM' })
          expect(response_json).to eq(expected_json)
        end
      end
    end
  end

  describe '#url' do
    it 'returns a url for the DDP session query endpoint' do
      expect(subject.url).to eq('https://example.com/api/session-query')
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
