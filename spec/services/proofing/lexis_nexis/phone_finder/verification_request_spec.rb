require 'rails_helper'

RSpec.describe Proofing::LexisNexis::PhoneFinder::VerificationRequest do
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      phone: '5551231234',
    }
  end
  let(:response_body) { LexisNexisFixtures.phone_finder_rdp1_success_response_json }
  subject { described_class.new(applicant:, config: LexisNexisFixtures.example_config) }

  it_behaves_like 'a lexisnexis request'

  describe '#body' do
    it 'returns a properly formed request body' do
      expect(subject.body).to eq(LexisNexisFixtures.phone_finder_request_json)
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
  end

  describe '#url' do
    it 'returns a url for the Phone Finder endpoint' do
      expect(subject.url).to eq(
        'https://example.com/restws/identity/v2/test_account/customers.gsa2.phonefinder.workflow/conversation',
      )
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
