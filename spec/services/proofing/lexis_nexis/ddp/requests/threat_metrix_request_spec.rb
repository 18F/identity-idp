require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Requests::ThreatMetrixRequest do
  let(:dob) { '1980-01-01' }
  let(:ssn) { '123-45-6789' }
  let(:ssn_hash_hmac_secret_key) { 'test-threatmetrix-ssn-hmac-secret-key' }
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: ssn,
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
      uuid: '00000000-0000-0000-0000-000000000000',
      workflow: 'idv',
    }
  end

  let(:response_body) { LexisNexisFixtures.threatmetrix_success_response_json }
  subject do
    described_class.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_policy)
      .and_return('test-policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_authentication_policy)
      .and_return('test-authentication-policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_ssn_hash_hmac_secret_key)
      .and_return(ssn_hash_hmac_secret_key)
  end

  describe '#body' do
    context 'Idv verification request' do
      let(:parsed_body) do
        JSON.parse(subject.body, symbolize_names: true)
      end
      let(:ssn_hash) { parsed_body[:ssn_hash] }

      it 'returns a properly formed request body' do
        response_json = JSON.parse(subject.body)
        expected_json = JSON.parse(LexisNexisFixtures.threatmetrix_request_json)
        expect(response_json).to eq(expected_json)
      end

      it 'hashes the normalized SSN with salted HMAC-SHA-512' do
        expect(ssn_hash).to eq(
          OpenSSL::HMAC.hexdigest('SHA512', ssn_hash_hmac_secret_key, '123456789'),
        )
      end

      it 'sends a 64-byte hash as 128 lowercase hexadecimal digits' do
        expect(ssn_hash).to match(/\A[0-9a-f]{128}\z/)
      end

      context 'with an unformatted SSN' do
        let(:ssn) { '123456789' }

        it 'generates the same hash as the formatted SSN' do
          expect(ssn_hash).to eq(
            OpenSSL::HMAC.hexdigest('SHA512', ssn_hash_hmac_secret_key, '123456789'),
          )
        end
      end

      context 'without an SSN' do
        let(:ssn) { nil }
        let(:ssn_hash_hmac_secret_key) { nil }

        it 'sets the national ID fields to empty strings and omits the SSN hash' do
          expect(parsed_body).to include(
            national_id_number: '',
            national_id_type: '',
          )
          expect(parsed_body).not_to have_key(:ssn_hash)
        end
      end

      context 'with an SSN containing no digits' do
        let(:ssn) { '---' }

        it 'sets the national ID fields to empty strings and omits the SSN hash' do
          expect(parsed_body).to include(
            national_id_number: '',
            national_id_type: '',
          )
          expect(parsed_body).not_to have_key(:ssn_hash)
        end
      end

      context 'without an SSN hash HMAC secret key' do
        let(:ssn_hash_hmac_secret_key) { nil }

        it 'omits the SSN hash' do
          expect(parsed_body).not_to have_key(:ssn_hash)
        end
      end

      context 'with a blank SSN hash HMAC secret key' do
        let(:ssn_hash_hmac_secret_key) { '' }

        it 'omits the SSN hash' do
          expect(parsed_body).not_to have_key(:ssn_hash)
        end
      end

      context 'with an SSN hash HMAC secret key shorter than 32 bytes' do
        let(:ssn_hash_hmac_secret_key) { 'a' * 31 }

        it 'raises a configuration error' do
          expect { subject.body }.to raise_error(
            RuntimeError,
            'ThreatMetrix SSN hash key must be at least 32 bytes',
          )
        end
      end

      context 'with a 32-byte SSN hash HMAC secret key' do
        let(:ssn_hash_hmac_secret_key) { 'a' * 32 }

        it 'includes the SSN hash' do
          expect(ssn_hash).to eq(
            OpenSSL::HMAC.hexdigest('SHA512', ssn_hash_hmac_secret_key, '123456789'),
          )
        end
      end

      context 'without an address line 2' do
        let(:applicant) do
          hash = super()
          hash.delete(:address2)
          hash
        end

        it 'sets StreetAddress2 to and empty string' do
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
          uuid: '00000000-0000-0000-0000-000000000000',
          workflow: 'auth',
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
        expected_json = JSON.parse(LexisNexisFixtures.threatmetrix_authentication_request_json)
        expect(response_json).to eq(expected_json)
      end

      context 'with service provider associated with user' do
        let(:applicant) do
          {
            threatmetrix_session_id: 'UNIQUE_SESSION_ID',
            email: 'test@example.com',
            request_ip: '127.0.0.1',
            uuid_prefix: 'SPNUM',
            uuid: '00000000-0000-0000-0000-000000000000',
            workflow: 'auth',
          }
        end

        it 'returns a properly formed request body' do
          response_json = JSON.parse(subject.body)

          base_json = JSON.parse(LexisNexisFixtures.threatmetrix_authentication_request_json)
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
