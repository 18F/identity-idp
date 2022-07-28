require 'rails_helper'

RSpec.shared_examples 'an invalid auth code error is raised' do
  it 'raises an error' do
    expect { subject.execute }.to raise_error 'The provided auth_code is blank?'
  end
end

RSpec.describe InheritedProofing::Va::Service do
  subject(:service) { described_class.new auth_code }

  before do
    allow(service).to receive(:private_key).and_return(private_key)
  end

  let(:auth_code) {}
  let(:private_key) { private_key_from_store_or(file_name: 'va_ip.key') }
  let(:payload) { { inherited_proofing_auth: auth_code, exp: 1.day.from_now.to_i } }
  let(:jwt_token) { JWT.encode(payload, private_key, 'RS256') }
  let(:request_uri) {
    "#{InheritedProofing::Va::Service::BASE_URI}/inherited_proofing/user_attributes"
  }
  let(:request_headers) { { Authorization: "Bearer #{jwt_token}" } }

  it { respond_to :execute }

  it do
    expect(service.send(:private_key)).to eq private_key
  end

  describe '#execute' do
    context 'when the auth code is valid' do
      let(:auth_code) { 'mocked-auth-code-for-testing' }

      it 'makes an authenticated request' do
        stub = stub_request(:get, request_uri).
          with(headers: request_headers).
          to_return(status: 200, body: '{}', headers: {})

        service.execute

        expect(stub).to have_been_requested.once
      end
    end

    context 'when the auth code is invalid' do
      context 'when an empty? string' do
        let(:auth_code) { '' }

        it_behaves_like 'an invalid auth code error is raised'
      end

      context 'when an nil?' do
        let(:auth_code) { nil }

        it_behaves_like 'an invalid auth code error is raised'
      end
    end
  end
end
