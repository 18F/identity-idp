require 'rails_helper'

RSpec.describe IrsAttemptsApi::Event do
  let(:irs_attempt_api_private_key) { OpenSSL::PKey::RSA.new(4096) }
  let(:irs_attempt_api_public_key) { irs_attempt_api_private_key.public_key }

  before do
    encoded_pubic_key = Base64.strict_encode64(irs_attempt_api_public_key.to_der)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
                                   and_return(encoded_pubic_key)
  end

  let(:event_type) { :test_event }
  let(:session_id) { 'test-session-id' }
  let(:occurred_at) { 1.hour.ago }
  let(:event_metadata) { { 'test_key' => 'test_value' } }

  subject do
    described_class.build(
      event_type: :test_event,
      session_id: 'test-session-id',
      occurred_at: occurred_at,
      event_metadata: event_metadata,
    )
  end

  describe '#security_event_token_data' do
    it 'returns a security event token string' do
      token = subject.security_event_token_data

      expect(token['iss']).to eq('http://www.example.com/')
      expect(token['jti']).to be_a(String)
      expect(Time.at(token['iat'])).to be_within(1.second).of(Time.now)
      expect(token['aud']).to eq('https://irs.gov')

      event_key = 'https://schemas.login.gov/secevent/irs-attempts-api/event-type/test-event'
      encrypted_event_data = token['events'][event_key]
      decrypted_event_data = irs_attempt_api_private_key.private_decrypt(
        Base64.strict_decode64(encrypted_event_data),
      )
      event_data = JSON.parse(decrypted_event_data)

      expect(event_data['subject']).to eq(
        'subject_type' => 'session', 'session_id' => 'test-session-id'
      )
      expect(event_data['test_key']).to eq('test_value')
      expect(Time.at(event_data['occurred_at'])).to be_within(1.second).of(occurred_at)
      expect(event_data['test_key']).to eq('test_value')
    end
  end

  describe '#jwt' do
    it 'returns a JWT encoded event' do
      jwt = subject.jwt

      jwt_payload, jwt_headers = JWT.decode(
        jwt,
        AppArtifacts.store.oidc_public_key,
        true,
        algorithm: 'RS256',
      )

      expect(jwt_payload).to eq(subject.security_event_token_data)
      expect(jwt_headers).to eq('typ'=>'secevent+jwt', 'alg'=>'RS256')
    end
  end
end
