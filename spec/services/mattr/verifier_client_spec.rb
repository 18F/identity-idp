require 'rails_helper'

RSpec.describe Mattr::VerifierClient do
  let(:client) { described_class.new }
  let(:tenant_url) { 'https://mdl-login.vii.us01.mattr.global' }
  let(:auth_url) { 'https://auth.us01.mattr.global' }
  let(:audience) { tenant_url }
  let(:client_id) { 'test-client-id' }
  let(:client_secret) { 'test-client-secret' }

  before do
    allow(IdentityConfig.store).to receive(:mattr_tenant_url).and_return(tenant_url)
    allow(IdentityConfig.store).to receive(:mattr_auth_url).and_return(auth_url)
    allow(IdentityConfig.store).to receive(:mattr_audience).and_return(audience)
    allow(IdentityConfig.store).to receive(:mattr_client_id).and_return(client_id)
    allow(IdentityConfig.store).to receive(:mattr_client_secret).and_return(client_secret)
    allow(IdentityConfig.store).to receive(:mattr_request_timeout).and_return(30)

    Rails.cache.delete(Mattr::VerifierClient::AUTH_TOKEN_CACHE_KEY)

    stub_request(:post, "#{auth_url}/oauth/token").to_return(
      status: 200,
      body: {
        access_token: 'test-access-token',
        token_type: 'Bearer',
        expires_in: 3600,
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  describe '#get_presentation_result' do
    let(:session_id) { 'session-abc-123' }

    before do
      stub_request(:get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result").to_return(
        status: 200,
        body: {
          challenge: 'test-challenge',
          credentials: [
            {
              verificationResult: { verified: true },
              claims: {
                'org.iso.18013.5.1' => {
                  'given_name' => { 'value' => 'JANE' },
                  'family_name' => { 'value' => 'DOE' },
                },
              },
            },
          ],
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'returns the verified presentation result' do
      result = client.get_presentation_result(session_id: session_id)

      expect(result['credentials'].first['verificationResult']['verified']).to eq(true)
      expect(result['credentials'].first['claims']['org.iso.18013.5.1']['given_name']['value'])
        .to eq('JANE')
    end
  end

  describe '#create_application' do
    before do
      stub_request(:post, "#{tenant_url}/v2/presentations/applications").to_return(
        status: 201,
        body: {
          id: 'app-id-123',
          name: 'Login.gov Verifier',
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'creates a verifier application' do
      result = client.create_application(
        name: 'Login.gov Verifier',
        domain: 'idp.identitysandbox.gov',
        redirect_uris: ['https://idp.identitysandbox.gov/idv/mdl/callback'],
      )

      expect(result['id']).to eq('app-id-123')
    end
  end

  describe '#create_wallet_provider' do
    before do
      stub_request(:post, "#{tenant_url}/v2/presentations/wallet-providers").to_return(
        status: 201,
        body: { id: 'wp-id-456', name: 'MATTR GO Hold' }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'creates a wallet provider' do
      result = client.create_wallet_provider(
        name: 'MATTR GO Hold',
        authorization_endpoint: 'mdoc-openid4vp://',
      )

      expect(result['id']).to eq('wp-id-456')
    end
  end

  describe '#add_trusted_issuer' do
    let(:cert_pem) { "-----BEGIN CERTIFICATE-----\nMIIBfake\n-----END CERTIFICATE-----" }

    before do
      stub_request(:post, "#{tenant_url}/v2/credentials/mobile/trusted-issuers").to_return(
        status: 201,
        body: { id: 'issuer-id-789' }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'registers a trusted issuer certificate' do
      result = client.add_trusted_issuer(certificate_pem: cert_pem)

      expect(result['id']).to eq('issuer-id-789')
    end
  end

  describe 'token caching' do
    let(:session_id) { 'session-abc-123' }

    before do
      stub_request(:get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result").to_return(
        status: 200,
        body: { credentials: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'fetches a token once and caches it across requests' do
      client.get_presentation_result(session_id: session_id)
      client.get_presentation_result(session_id: session_id)

      expect(WebMock).to have_requested(:post, "#{auth_url}/oauth/token").once
    end

    it 'sends the cached token in the Authorization header' do
      client.get_presentation_result(session_id: session_id)

      expect(WebMock).to have_requested(
        :get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result"
      ).with(headers: { 'Authorization' => 'Bearer test-access-token' })
    end
  end

  describe 'error handling' do
    let(:session_id) { 'missing-session' }

    before do
      stub_request(:get, "#{tenant_url}/v2/presentations/sessions/#{session_id}/result").to_return(
        status: 404,
        body: { error: 'NotFound' }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'raises a Faraday error for non-2xx responses' do
      expect do
        client.get_presentation_result(session_id: session_id)
      end.to raise_error(Faraday::ResourceNotFound)
    end
  end
end
