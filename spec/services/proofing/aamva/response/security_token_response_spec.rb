require 'rails_helper'

RSpec.describe Proofing::Aamva::Response::SecurityTokenResponse do
  let(:security_context_token_identifier) { 'sct-token-identifier' }
  let(:security_context_token_reference) { 'sct-token-reference' }
  let(:nonce) { 'MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE=' }

  let(:status_code) { 200 }
  let(:response_body) { AamvaFixtures.security_token_response }
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

    context 'when the API response is an error' do
      let(:response_body) { AamvaFixtures.soap_fault_response_simplified }

      it 'raises an AuthenticationError' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'A FooBar error occurred',
        )
      end
    end

    context 'when the security context token is missing' do
      let(:response_body) { delete_xml_at_xpath(super(), '//c:SecurityContextToken') }

      it 'should raise an error' do
        expect { subject }.to raise_error(
          Proofing::Aamva::AuthenticationError,
          'The authentication response is missing a security context token',
        )
      end
    end
  end

  describe '#security_context_token_identifier' do
    it 'returns the security token identifier from the request' do
      expect(subject.security_context_token_identifier).to eq(security_context_token_identifier)
    end
  end

  describe '#security_context_token_reference' do
    it 'returns the security context token reference from the request' do
      expect(subject.security_context_token_reference).to eq(security_context_token_reference)
    end
  end

  describe '#nonce' do
    it 'returns the nonce from the request' do
      expect(subject.nonce).to eq(subject.nonce)
    end
  end
end
