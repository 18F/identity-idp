require 'rails_helper'

RSpec.describe AttemptsApi::HistoricalAttemptEvent do
  let(:attempts_api_private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:attempts_api_public_key) { attempts_api_private_key.public_key }

  let(:signing_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:signing_private_key) { signing_key.private_to_pem }
  let(:signing_public_key) { OpenSSL::PKey::EC.new(signing_key.public_to_pem) }

  let(:jti) { 'test-unique-id' }
  let(:iat) { Time.zone.now.to_i }
  let(:event_type) { 'idv-test-event' }
  let(:session_id) { 'test-session-id' }
  let(:occurred_at) { Time.zone.now.round }
  let(:service_provider) { create(:service_provider, :idv) }
  let(:user) { create(:user) }
  let(:proofing_identity) { AgencyIdentityLinker.for(user:, service_provider:, skip_create: false) }
  let(:aaca_sp) { create(:service_provider, :idv) }
  let!(:aaca_identity) do
    AgencyIdentityLinker.for(user:, service_provider: aaca_sp, skip_create: false)
  end
  let(:user_uuid) { proofing_identity.uuid }

  let(:event_data) do
    {
      jti:,
      iat:,
      occurred_at:,
      event_type:,
      session_id:,
      event_metadata: {
        user_uuid:,
        application_url: 'https://example.com/app',
        client_port: '8080',
      },
    }.as_json
  end

  subject do
    described_class.new(event_data:, sp: aaca_sp)
  end

  describe '#initialize' do
    it 'initializes the event with the correct event data' do
      expect(subject.jti).to eq(jti)
      expect(subject.iat).to eq(iat)
      expect(subject.event_type).to eq(event_type)
      expect(subject.session_id).to eq(session_id)
      expect(subject.occurred_at).to eq(occurred_at)
      expect(subject.event_metadata).to eq(
        {
          'user_uuid' => aaca_identity.uuid,
          'application_url' => nil,
          'client_port' => nil,
        },
      )
    end

    context 'when the user is not found' do
      let(:user_uuid) { 'non-existent-uuid' }

      it 'initializes the event with nil user_uuid in metadata' do
        expect(subject.event_metadata['user_uuid']).to be_nil
      end
    end
  end
end
