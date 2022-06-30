require 'rails_helper'

RSpec.describe IrsAttemptsApi::AttemptEvent do
  let(:irs_attempt_api_private_key) { OpenSSL::PKey::RSA.new(4096) }
  let(:irs_attempt_api_public_key) { irs_attempt_api_private_key.public_key }

  before do
    encoded_pubic_key = Base64.strict_encode64(irs_attempt_api_public_key.to_der)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_public_key).
                                   and_return(encoded_pubic_key)
  end

  let(:jti) { 'test-unique-id' }
  let(:iat) { Time.zone.now.to_i }
  let(:event_type) { 'test-event' }
  let(:session_id) { 'test-session-id' }
  let(:occurred_at) { Time.zone.now.round }
  let(:event_metadata) { { 'foo' => 'bar' } }

  subject do
    described_class.new(
      jti: jti,
      iat: iat,
      event_type: event_type,
      session_id: session_id,
      occurred_at: occurred_at,
      event_metadata: event_metadata,
    )
  end

  describe '#to_jwe' do
    it 'returns a JWE for the event' do
      jwe = subject.to_jwe

      decrypted_jwe_payload = JWE.decrypt(jwe, irs_attempt_api_private_key)
      token = JSON.parse(decrypted_jwe_payload)

      expect(token['iss']).to eq('http://www.example.com/')
      expect(token['jti']).to eq(jti)
      expect(token['iat']).to eq(iat)
      expect(token['aud']).to eq('https://irs.gov')

      event_key = 'https://schemas.login.gov/secevent/irs-attempts-api/event-type/test-event'
      event_data = token['events'][event_key]

      expect(event_data['subject']).to eq(
        'subject_type' => 'session', 'session_id' => 'test-session-id',
      )
      expect(event_data['foo']).to eq('bar')
      expect(event_data['occurred_at']).to eq(occurred_at.to_i)
    end
  end

  describe '.from_jwe' do
    it 'returns an event decrypted from the JWE' do
      jwe = subject.to_jwe

      decrypted_event = described_class.from_jwe(jwe, irs_attempt_api_private_key)

      expect(decrypted_event.jti).to eq(subject.jti)
      expect(decrypted_event.iat).to eq(subject.iat)
      expect(decrypted_event.event_type).to eq(subject.event_type)
      expect(decrypted_event.session_id).to eq(subject.session_id)
      expect(decrypted_event.occurred_at).to eq(subject.occurred_at)
      expect(decrypted_event.event_metadata).to eq(subject.event_metadata.symbolize_keys)
    end
  end
end
