require 'rails_helper'

RSpec.describe Proofing::Aamva::Request::AuthenticationTokenRequest do
  let(:security_context_token_identifier) { 'sct-token-identifier' }
  let(:security_context_token_reference) { 'sct-token-reference' }
  let(:client_hmac_secret) { 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=' }
  let(:server_hmac_secret) { 'MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE=' }

  let(:config) do
    AamvaFixtures.example_config
  end

  subject do
    described_class.new(
      config:,
      security_context_token_identifier:,
      security_context_token_reference:,
      client_hmac_secret:,
      server_hmac_secret:,
    )
  end

  before do
    allow(Time).to receive(:now).and_return(Time.utc(2017))
    allow(SecureRandom).to receive(:uuid).
      at_least(:once).
      and_return('12345678-abcd-efgh-ijkl-1234567890ab')
  end

  describe '#body' do
    it 'should be a signed request body' do
      expect(subject.body).to eq(AamvaFixtures.authentication_token_request)
    end
  end

  describe '#headers' do
    it 'should return valid SOAP headers' do
      expect(subject.headers).to eq(
        'SOAPAction' =>
          '"http://aamva.org/authentication/3.1.0/IAuthenticationService/Authenticate"',
        'Content-Type' => 'application/soap+xml;charset=UTF-8',
        'Content-Length' => subject.body.length.to_s,
      )
    end
  end

  describe '#url' do
    it 'should be the AAMVA authentication url' do
      expect(subject.url).to eq(
        'https://authentication-cert.example.com/Authentication/Authenticate.svc',
      )
    end
  end

  describe '#send' do
    context 'when the request is successful' do
      it 'returns a response object' do
        stub_request(:post, config.auth_url).
          to_return(body: AamvaFixtures.authentication_token_response, status: 200)

        result = subject.send

        expect(result.auth_token).to eq('KEYKEYKEY')
      end
    end

    # rubocop:disable Layout/LineLength
    context 'when the request times out' do
      it 'raises an error' do
        stub_request(:post, config.auth_url).
          to_timeout

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for authentication token response: execution expired',
        )
      end
    end
    # rubocop:enable Layout/LineLength

    context 'when the connection fails' do
      it 'raises an error' do
        stub_request(:post, config.auth_url).
          to_raise(Faraday::ConnectionFailed.new('error'))

        expect { subject.send }.to raise_error(
          ::Proofing::TimeoutError,
          'AAMVA raised Faraday::ConnectionFailed waiting for authentication token response: error',
        )
      end
    end
  end

  describe '#timeout' do
    let(:config) do
      super().tap do |config|
        config.auth_request_timeout = 100
      end
    end

    it 'reads from the config object' do
      expect(subject.instance_eval { timeout }).to eq(100)
    end
  end
end
