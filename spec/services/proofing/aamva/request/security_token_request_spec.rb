require 'rails_helper'
require 'rexml/document'
require 'rexml/xpath'

describe Proofing::Aamva::Request::SecurityTokenRequest do
  let(:config) { AamvaFixtures.example_config }

  before do
    allow(Time).to receive(:now).and_return(Time.utc(2017))
    allow(SecureRandom).to receive(:base64).
      with(32).
      and_return('MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=')
    allow(SecureRandom).to receive(:uuid).
      at_least(:once).
      and_return('12345678-abcd-efgh-ijkl-1234567890ab')
  end

  subject(:security_token_request) { described_class.new(config) }

  describe '#body' do
    it 'should be a signed request body' do
      document = REXML::Document.new(security_token_request.body)
      public_key = REXML::XPath.first(document, '//wsse:BinarySecurityToken')
      signature = REXML::XPath.first(document, '//ds:SignatureValue')
      key_identifier = REXML::XPath.first(document, '//wsse:KeyIdentifier')

      expect(public_key.text).to eq Base64.strict_encode64(AamvaFixtures.aamva_public_key.to_der)
      expect(key_identifier.text).to_not be_nil
      expect(key_identifier.text).to_not be_empty
      expect(signature.text).to_not be_nil
      expect(signature.text).to_not be_empty

      body_without_sig = security_token_request.body.
        gsub(public_key.text, '').
        gsub(signature.text, '').
        gsub(key_identifier.text, '')

      expect(body_without_sig).to eq(AamvaFixtures.security_token_request)
    end
  end

  describe '#headers' do
    it 'should return valid SOAP headers' do
      expect(security_token_request.headers).to eq(
        'SOAPAction' =>
          '"http://aamva.org/authentication/3.1.0/IAuthenticationService/Authenticate"',
        'Content-Type' => 'application/soap+xml;charset=UTF-8',
        'Content-Length' => security_token_request.body.length.to_s,
      )
    end
  end

  describe '#url' do
    it 'should be the AAMVA authentication url' do
      expect(security_token_request.url).to eq(
        'https://authentication-cert.example.com/Authentication/Authenticate.svc',
      )
    end
  end

  describe '#send' do
    context 'when the request is successful' do
      it 'returns a response object' do
        stub_request(:post, config.auth_url).
          to_return(body: AamvaFixtures.security_token_response, status: 200)

        result = security_token_request.send

        expect(result.nonce).to eq('MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE=')
      end
    end

    context 'when the request times out once' do
      it 'retries and tries again' do
        stub_request(:post, config.auth_url).
          to_timeout.
          to_return(body: AamvaFixtures.security_token_response, status: 200)

        result = security_token_request.send

        expect(result.nonce).to eq('MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE=')
      end
    end

    # rubocop:disable Layout/LineLength
    context 'when the request times out a second time' do
      it 'raises an error' do
        stub_request(:post, config.auth_url).
          to_timeout

        expect { security_token_request.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for security token response: execution expired',
        )
      end
    end
    # rubocop:enable Layout/LineLength

    context 'when the connection fails' do
      it 'raises an error' do
        stub_request(:post, config.auth_url).
          to_raise(Faraday::ConnectionFailed.new('error'))

        expect { security_token_request.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for security token response: error',
        )
      end
    end
  end
end
