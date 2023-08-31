require 'rails_helper'

RSpec.describe Proofing::Aamva::Response::AuthenticationTokenResponse do
  let(:status_code) { 200 }
  let(:response_body) { AamvaFixtures.authentication_token_response }
  let(:http_response) do
    response = Faraday::Response.new
    allow(response).to receive(:status).and_return(status_code)
    allow(response).to receive(:body).and_return(response_body)
    response
  end

  subject do
    described_class.new(http_response)
  end

  describe '#initialize' do
    context 'with a non-200 status code' do
      let(:status_code) { 500 }

      it 'raises an AuthenticationError' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'Unexpected status code in response: 500',
        )
      end
    end

    context 'with a non-200 status code and a non-xml body' do
      let(:status_code) { 504 }
      let(:response_body) { '<h1>Oh no</h1><hr><p>This is not xml.' }

      it 'raises a AuthenticationError' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'Unexpected status code in response: 504',
        )
      end
    end

    context 'when the API response has an error' do
      let(:response_body) { AamvaFixtures.soap_fault_response_simplified }

      it 'raises an AuthenticationError' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'A FooBar error occurred',
        )
      end
    end

    context 'when the API response is missing a token' do
      let(:response_body) do
        delete_xml_at_xpath(
          AamvaFixtures.authentication_token_response,
          '//Token',
        )
      end

      it 'raises an AuthenticationError' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'The authentication response is missing a token',
        )
      end
    end
  end

  describe '#auth_token' do
    it 'returns the token from the response body' do
      expect(subject.auth_token).to eq('KEYKEYKEY')
    end
  end
end
