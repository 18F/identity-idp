require 'rails_helper'

RSpec.describe Proofing::Aamva::AuthenticationClient do
  let(:config) { AamvaFixtures.example_config }
  let(:security_token_request_stub) do
    stub_request(:post, config.auth_url).
      with(body: AamvaFixtures.security_token_request).
      to_return(body: AamvaFixtures.security_token_response, status: 200)
  end
  let(:auth_token_request_stub) do
    stub_request(:post, config.auth_url).
      with(body: AamvaFixtures.authentication_token_request).
      to_return(body: AamvaFixtures.authentication_token_response, status: 200)
  end

  let(:security_context_token_identifier) { 'sct-token-identifier' }
  let(:security_context_token_reference) { 'sct-token-reference' }
  let(:client_hmac_secret) { 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=' }
  let(:server_hmac_secret) { 'MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE=' }

  describe '#fetch_token' do
    before do
      security_token_request = Proofing::Aamva::Request::SecurityTokenRequest.new(config)
      allow(security_token_request).to receive(:body).
        and_return(AamvaFixtures.security_token_request)
      allow(security_token_request).to receive(:nonce).and_return(client_hmac_secret)
      allow(Proofing::Aamva::Request::SecurityTokenRequest).to receive(:new).
        and_return(security_token_request)
      security_token_request_stub

      auth_token_request = Proofing::Aamva::Request::AuthenticationTokenRequest.new(
        security_context_token_identifier: security_context_token_identifier,
        security_context_token_reference: security_context_token_reference,
        client_hmac_secret: client_hmac_secret,
        server_hmac_secret: server_hmac_secret,
        config: config,
      )
      allow(auth_token_request).to receive(:body).
        and_return(AamvaFixtures.authentication_token_request)
      allow(Proofing::Aamva::Request::AuthenticationTokenRequest).to receive(:new).
        with(
          config: config,
          security_context_token_identifier: security_context_token_identifier,
          security_context_token_reference: security_context_token_reference,
          client_hmac_secret: client_hmac_secret,
          server_hmac_secret: server_hmac_secret,
        ).
        and_return(auth_token_request)
      auth_token_request_stub
    end

    context 'when the auth token is not set' do
      it 'should send an authentication request then save and return the token' do
        token = Proofing::Aamva::AuthenticationClient.auth_token(AamvaFixtures.example_config)
        token2 = Proofing::Aamva::AuthenticationClient.auth_token(AamvaFixtures.example_config)

        expect(token).to eq('KEYKEYKEY')
        expect(token2).to eq('KEYKEYKEY')
        expect(security_token_request_stub).to have_been_requested.once
        expect(auth_token_request_stub).to have_been_requested.once
      end
    end

    context 'when the auth token is present and fresh' do
      before do
        Rails.cache.write(
          Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY,
          'THEOTHERKEY',
          expires_in: Proofing::Aamva::AuthenticationClient::AAMVA_TOKEN_FRESHNESS_SECONDS,
        )
      end

      it 'should return the auth token' do
        token = Proofing::Aamva::AuthenticationClient.auth_token(AamvaFixtures.example_config)
        expect(token).to eq('THEOTHERKEY')

        expect(security_token_request_stub).to_not have_been_requested
        expect(auth_token_request_stub).to_not have_been_requested
      end
    end
  end
end
