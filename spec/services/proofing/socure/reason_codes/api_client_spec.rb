require 'rails_helper'

RSpec.describe Proofing::Socure::ReasonCodes::ApiClient do
  before do
    allow(IdentityConfig.store).to receive(
      :socure_reason_code_base_url,
    ).and_return(
      'https://example.org/',
    )
  end

  it 'returns a parsed set or reason codes' do
    api_response_body = {
      'reasonCodes' => {
        'ProductA' => {
          'A1' => 'test1',
          'A2' => 'test2',
        },
        'ProductB' => {
          'B2' => 'test3',
        },
      },
    }.to_json
    stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
      headers: { 'Content-Type' => 'application/json' },
      body: api_response_body,
    )

    result = described_class.new.download_reason_codes

    expect(result).to eq(
      'ProductA' => {
        'A1' => 'test1',
        'A2' => 'test2',
      },
      'ProductB' => {
        'B2' => 'test3',
      },
    )
  end

  context 'the authentication to the service fails' do
    it 'raises an unauthorized error' do
      stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
        status: 401,
        headers: {
          'Content-Type' => 'application/json',
        },
        body: {
          status: 'Error',
          referenceId: 'a-big-unique-reference-id',
          msg: 'Request-specific error message goes here',
        }.to_json,
      )

      expect { described_class.new.download_reason_codes }.to raise_error(
        Proofing::Socure::ReasonCodes::ApiClient::ApiClientError,
        'the server responded with status 401',
      )
    end
  end

  context 'there is a networking error in the request' do
    it 'raises the error' do
      stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_timeout

      expect { described_class.new.download_reason_codes }.to raise_error(
        Proofing::Socure::ReasonCodes::ApiClient::ApiClientError,
        'execution expired',
      )
    end
  end

  context 'the response includes invalid JSON' do
    it 'raises a parsing error' do
      stub_request(:get, 'https://example.org/api/3.0/reasoncodes?group=true').to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: '{;*[("',
      )

      expect { described_class.new.download_reason_codes }.to raise_error(
        Proofing::Socure::ReasonCodes::ApiClient::ApiClientError,
        "unexpected token at '{;*[(\"'",
      )
    end
  end
end
