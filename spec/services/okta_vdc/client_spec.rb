require 'rails_helper'

RSpec.describe OktaVdc::Client do
  let(:client) { described_class.new }
  let(:base_url) { 'https://credentials.okta.com' }
  let(:auth_url) { OktaVdc::Client::DEFAULT_AUTH_URL }
  let(:client_id) { 'test-client-id' }
  let(:client_secret) { 'test-client-secret' }

  before do
    allow(IdentityConfig.store).to receive(:okta_vdc_base_url).and_return(base_url)
    allow(IdentityConfig.store).to receive(:okta_vdc_client_id).and_return(client_id)
    allow(IdentityConfig.store).to receive(:okta_vdc_client_secret).and_return(client_secret)
    allow(IdentityConfig.store).to receive(:okta_vdc_oauth_domain).and_return('')
    allow(IdentityConfig.store).to receive(:okta_vdc_request_timeout).and_return(30)

    stub_request(:post, "#{auth_url}/oauth/token").to_return(
      status: 200,
      body: {
        access_token: 'test-token',
        token_type: 'Bearer',
        expires_in: 3600,
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  describe '#create_credential_request' do
    let(:session_id) { 'test-session-123' }

    before do
      stub_request(:post, "#{base_url}/v1/verify/initiate").to_return(
        status: 200,
        body: {
          state: { sessionId: session_id, nonce: 'test-nonce' },
          requests: [{ protocol: 'openid4vp', data: { request: 'test' } }],
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'creates a credential request and returns session data' do
      result = client.create_credential_request(response_mode: 'dc_api')

      expect(result['state']['sessionId']).to eq(session_id)
      expect(result['requests']).to be_present
    end
  end

  describe '#get_claims' do
    let(:session_id) { 'test-session-123' }

    before do
      stub_request(:post, "#{base_url}/v1/verify/sessions/#{session_id}/claims").to_return(
        status: 200,
        body: {
          status: 'COMPLETED',
          claims: {
            'org.iso.18013.5.1' => {
              'given_name' => 'Fakey',
              'family_name' => 'McFakerson',
            },
          },
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'returns verified claims' do
      result = client.get_claims(
        session_id: session_id,
        authorization_response: 'test-auth-response',
      )

      expect(result['status']).to eq('COMPLETED')
      expect(result['claims']['org.iso.18013.5.1']['given_name']).to eq('Fakey')
    end
  end

  describe '#get_request_status' do
    let(:session_id) { 'test-session-123' }

    before do
      stub_request(:get, "#{base_url}/v1/verify/sessions/#{session_id}/status").to_return(
        status: 200,
        body: { status: 'PENDING' }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )
    end

    it 'returns the request status' do
      result = client.get_request_status(session_id: session_id)
      expect(result['status']).to eq('PENDING')
    end
  end
end
