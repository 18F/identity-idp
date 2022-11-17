require 'rails_helper'

RSpec.shared_examples 'an invalid auth code error is raised' do
  it 'raises an error' do
    expect { subject.execute }.to raise_error 'The provided auth_code is blank?'
  end
end

RSpec.describe Idv::InheritedProofing::Va::Service do
  include_context 'va_api_context'
  include_context 'va_user_context'

  subject(:service) { described_class.new(auth_code: auth_code) }

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

    context 'when a request error is raised' do
      before do
        allow(service).to receive(:request).and_raise('Boom!')
      end

      it 'rescues and returns the error' do
        expect(service.execute).to eq({ service_error: 'Boom!' })
      end
    end

    context 'when a decryption error is raised' do
      it 'rescues and returns the error' do
        freeze_time do
          stub_request(:get, request_uri).
            with(headers: request_headers).
            to_return(status: 200, body: 'xyz', headers: {})

          expect(service.execute[:service_error]).to match(/unexpected token at 'xyz'/)
        end
      end
    end

    context 'when a non-200 error is raised' do
      it 'rescues and returns the error' do
        freeze_time do
          stub_request(:get, request_uri).
            with(headers: request_headers).
            to_return(status: 302, body: encrypted_user_attributes, headers: {})

          expect(service.execute.to_s).to \
            match(/The service provider API returned an http status other than 200/)
        end
      end

      context 'when http status is unavailable (nil)' do
        before do
          allow_any_instance_of(Faraday::Response).to receive(:status).and_return(nil)
        end

        let(:expected_error) do
          {
            service_error: 'The service provider API returned an http status other than 200: ' \
              'unavailable (unavailable)',
          }
        end

        it 'rescues and returns the error' do
          freeze_time do
            stub_request(:get, request_uri).
              with(headers: request_headers).
              to_return(status: nil, body: encrypted_user_attributes, headers: {})

            expect(service.execute).to eq expected_error
          end
        end
      end
    end
  end
end
