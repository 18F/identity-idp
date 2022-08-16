require 'rails_helper'

RSpec.shared_examples 'an invalid auth code error is raised' do
  it 'raises an error' do
    expect { subject.execute }.to raise_error 'The provided auth_code is blank?'
  end
end

RSpec.describe Idv::InheritedProofing::Va::Service do
  include_context 'va_api_context'
  include_context 'va_user_context'

  subject(:service) { described_class.new auth_code }

  before do
    allow(service).to receive(:private_key).and_return(private_key)
  end

  it { respond_to :execute }

  it do
    expect(service.send(:private_key)).to eq private_key
  end

  describe '#execute' do
    context 'when the auth code is valid' do
      let(:auth_code) { 'mocked-auth-code-for-testing' }

      it 'makes an authenticated request' do
        freeze_time do
          stub = stub_request(:get, request_uri).
            with(headers: request_headers).
            to_return(status: 200, body: '{}', headers: {})

          service.execute

          expect(stub).to have_been_requested.once
        end
      end

      it 'decrypts the response' do
        freeze_time do
          stub_request(:get, request_uri).
            with(headers: request_headers).
            to_return(status: 200, body: encrypted_user_attributes, headers: {})

          expect(service.execute).to eq user_attributes
        end
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
