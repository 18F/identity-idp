require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Requests::InstantVerifyRequest do
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
      uuid_prefix: 'ABCD',
      uuid: '00000000-0000-0000-0000-000000000000',
      workflow: 'idv',
    }
  end

  let(:response_body) { LexisNexisFixtures.ddp_instant_verify_success_response_json }
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
  end

  describe '#body' do
    context 'Idv verification request' do
      it 'returns a properly formed request body' do
        response_json = JSON.parse(subject.body)
        expected_json = JSON.parse(LexisNexisFixtures.ddp_instant_verify_request_json)
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

      context 'without a state' do
        let(:applicant) do
          hash = super()
          hash.delete(:state)
          hash
        end

        it 'sets account_address_country to an empty string' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:account_address_country]).to eq('')
        end
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

      context 'without an ssn' do
        let(:applicant) do
          hash = super()
          hash.delete(:ssn)
          hash
        end

        it 'sets national_id_number and national_id_type to empty strings' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:national_id_number]).to eq('')
          expect(parsed_body[:national_id_type]).to eq('')
        end
      end

      context 'without a state_id_number' do
        let(:applicant) do
          hash = super()
          hash.delete(:state_id_number)
          hash
        end

        it 'sets account_drivers_license_number & account_drivers_license_type to empty strings' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:account_drivers_license_number]).to eq('')
          expect(parsed_body[:account_drivers_license_type]).to eq('')
        end
      end

      context 'without a state_id_jurisdiction' do
        let(:applicant) do
          hash = super()
          hash.delete(:state_id_jurisdiction)
          hash
        end

        it 'sets account_drivers_license_issuer to an empty string' do
          parsed_body = JSON.parse(subject.body, symbolize_names: true)
          expect(parsed_body[:account_drivers_license_issuer]).to eq('')
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
