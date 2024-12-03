require 'rails_helper'

RSpec.describe AttemptsApi::AttemptEvent do
  let(:attempts_api_private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:attempts_api_public_key) { attempts_api_private_key.public_key }

  let(:jti) { 'test-unique-id' }
  let(:iat) { Time.zone.now.to_i }
  let(:event_type) { 'test-event' }
  let(:session_id) { 'test-session-id' }
  let(:occurred_at) { Time.zone.now.round }
  let(:event_metadata) { { 'foo' => 'bar' } }
  let(:service_provider) { build(:service_provider) }

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
      jwe = subject.to_jwe(issuer: service_provider.issuer, public_key: attempts_api_public_key)

      header_str, *_rest = JWE::Serialization::Compact.decode(jwe)
      headers = JSON.parse(header_str)

      expect(headers['alg']).to eq('RSA-OAEP')
      # expect(headers['kid']).to eq(JWT::JWK.new(attempts_api_public_key).kid)

      decrypted_jwe_payload = JWE.decrypt(jwe, attempts_api_private_key)

      token = JSON.parse(decrypted_jwe_payload)

      expect(token['iss']).to eq(Rails.application.routes.url_helpers.root_url)
      expect(token['jti']).to eq(jti)
      expect(token['iat']).to eq(iat)
      expect(token['aud']).to eq(service_provider.issuer)

      event_key = 'https://schemas.login.gov/secevent/attempts-api/event-type/test-event'
      event_data = token['events'][event_key]

      expect(event_data['subject']).to eq(
        'subject_type' => 'session', 'session_id' => 'test-session-id',
      )
      expect(event_data['foo']).to eq('bar')
      expect(event_data['occurred_at']).to eq(occurred_at.to_f)
    end
  end

  describe '.from_jwe' do
    it 'returns an event decrypted from the JWE' do
      jwe = subject.to_jwe(issuer: service_provider.issuer, public_key: attempts_api_public_key)

      decrypted_event = described_class.from_jwe(jwe, attempts_api_private_key)

      expect(decrypted_event.jti).to eq(subject.jti)
      expect(decrypted_event.iat).to eq(subject.iat)
      expect(decrypted_event.event_type).to eq(subject.event_type)
      expect(decrypted_event.session_id).to eq(subject.session_id)
      expect(decrypted_event.occurred_at).to eq(subject.occurred_at)
      expect(decrypted_event.event_metadata).to eq(subject.event_metadata.symbolize_keys)
    end
  end
end
