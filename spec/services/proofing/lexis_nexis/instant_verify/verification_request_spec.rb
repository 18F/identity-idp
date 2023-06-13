require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::VerificationRequest do
  let(:dob) { '01/01/1980' }
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123-45-6789',
      dob: dob,
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '132465879',
      state_id_jurisdiction: 'LA',
      state_id_type: 'drivers_license',
    }
  end
  let(:response_body) { LexisNexisFixtures.instant_verify_success_response_json }
  subject { described_class.new(applicant: applicant, config: LexisNexisFixtures.example_config) }

  it_behaves_like 'a lexisnexis request'

  describe '#body' do
    it 'returns a properly formed request body' do
      expect(subject.body).to eq(LexisNexisFixtures.instant_verify_request_json)
    end

    context 'without an address line 2' do
      let(:applicant) do
        hash = super()
        hash.delete(:address2)
        hash
      end

      it 'sets StreetAddress2 to and empty string' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body[:Person][:Addresses][0][:StreetAddress2]).to eq('')
      end
    end

    context 'without a uuid_prefix' do
      let(:applicant) do
        hash = super()
        hash.delete(:uuid_prefix)
        hash
      end

      it 'does not prepend' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body[:Settings][:Reference]).to eq(applicant[:uuid])
      end
    end

    context 'with an international-formatted dob' do
      let(:dob) { '1980-01-01' }

      it 'formats the DOB correctly' do
        parsed_body = JSON.parse(subject.body, symbolize_names: true)
        expect(parsed_body.dig(:Person, :DateOfBirth, :Year)).to eq('1980')
      end
    end
  end

  describe '#url' do
    it 'returns a url for the Instant Verify endpoint' do
      expect(subject.url).to eq('https://example.com/restws/identity/v2/test_account/gsa2.chk32.test.wf/conversation')
    end
  end

  describe '#build_request_headers' do
    context 'HMAC Auth disabled' do
      before do
        allow(IdentityConfig.store).to receive(:lexisnexis_hmac_auth_enabled).and_return(false)
      end

      it 'does not include a HMAC Authorization header' do
        expect(subject.send(:build_request_headers)['Authorization']).to be_nil
      end
    end

    context 'HMAC Auth enabled' do
      let(:token) do
        'HMAC-SHA256 keyid=HMAC-KEY-ID ts=timestamp nonce=nonce bodyHash=base64digest signature=sig'
      end

      before do
        allow(IdentityConfig.store).to receive(:lexisnexis_hmac_auth_enabled).and_return(true)
        allow(subject).to receive(:hmac_authorization).and_return(token)
      end

      it 'includes an Authorization header with the HMAC token' do
        expect(subject.send(:build_request_headers)['Authorization']).to eq(token)
      end
    end
  end
end
