require 'rails_helper'

RSpec.describe AttemptsApi::DelegatedEventWriter do
  let(:recipient) { create(:service_provider, :delegation_application) }
  let(:analytics) { FakeAnalytics.new }
  let(:redis_client) { AttemptsApi::RedisClient.new }
  let(:allowed_attempts_providers) { [{ 'issuer' => recipient.issuer, 'keys' => [] }] }
  let(:event) do
    AttemptsApi::AttemptEvent.new(
      event_type: 'login-completed',
      session_id: 'sp-session-id',
      occurred_at: Time.zone.now,
      event_metadata: {
        user_uuid: 'sp-agency-uuid',
        google_analytics_cookies: { '_ga' => 'GA1.x' },
        user_ip_address: '192.0.2.1',
        user_agent: 'example/1.0',
        device_id: 'device-1',
        application_url: 'https://mybenefits.example.gov/return',
        success: true,
      },
    )
  end

  subject(:writer) do
    described_class.new(
      recipient:, agency_uuid: 'agency-uuid', delegation_id: 'dlg_1',
      actor_issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', analytics:
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      attempts_api_enabled: true,
      token_exchange_enabled: true,
      token_exchange_attempts_delivery_enabled: true,
      allowed_attempts_providers:,
    )
  end

  def delivered_events
    redis_client.read_events(issuer: recipient.issuer).values.map do |jwe|
      AttemptsApi::AttemptEvent.from_jwe(jwe, saml_test_sp_private_key)
    end
  end

  describe '#forward' do
    it 're-maps the event for the agency and writes it under the recipient issuer' do
      copy = writer.forward(event)

      expect(copy.event_type).to eq('login-completed')
      expect(copy.session_id).to eq('sp-session-id')
      expect(copy.jti).to eq(event.jti)
      expect(copy.event_metadata).to include(
        user_uuid: 'agency-uuid',
        delegation_id: 'dlg_1',
        actor_issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        user_ip_address: '192.0.2.1',
        user_agent: 'example/1.0',
        device_id: 'device-1',
        application_url: 'https://mybenefits.example.gov/return',
        success: true,
      )
      expect(copy.event_metadata).not_to have_key(:google_analytics_cookies)

      stored = delivered_events
      expect(stored.map(&:jti)).to eq([event.jti])
      expect(stored.first.event_metadata).to include(
        user_uuid: 'agency-uuid',
        delegation_id: 'dlg_1',
      )
      expect(analytics).to have_logged_event(
        :delegated_access_attempts_delivery,
        event_type: 'login-completed',
        recipient_issuer: recipient.issuer,
        actor_issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
        success: true,
        event_count: 1,
      )
    end
  end

  describe '#forward_all' do
    it 'writes every copy and logs one outcome' do
      other = AttemptsApi::AttemptEvent.new(
        event_type: 'mfa-login-auth-submitted', session_id: 'sp-session-id',
        occurred_at: Time.zone.now, event_metadata: { success: true }
      )

      copies = writer.forward_all([event, other])

      expect(copies.map(&:event_type)).to eq(['login-completed', 'mfa-login-auth-submitted'])
      expect(delivered_events.map(&:jti)).to match_array([event.jti, other.jti])
      expect(analytics).to have_logged_event(
        :delegated_access_attempts_delivery,
        hash_including(event_type: 'buffered_session_events', success: true, event_count: 2),
      )
    end

    it 'does nothing with no events' do
      expect(writer.forward_all([])).to eq([])
      expect(analytics).not_to have_logged_event(:delegated_access_attempts_delivery)
    end
  end

  describe 'written events' do
    subject(:writer) do
      described_class.new(
        recipient:, agency_uuid: 'agency-uuid', delegation_id: 'dlg_1',
        actor_issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', analytics:,
        extra_metadata: { unique_session_id: 'session-hash' }
      )
    end

    it 'writes a server-side event with the join keys and no network details' do
      freeze_time do
        written = writer.delegated_access_consented(
          application: recipient.issuer, scope: 'token_exchange:housing_records',
          remembered: false, source: 'consent_screen', consented_at: Time.zone.now.to_f
        )

        expect(written.event_type).to eq('delegated-access-consented')
        expect(written.session_id).to be_nil
        expect(written.occurred_at).to eq(Time.zone.now)
        expect(written.event_metadata).to include(
          user_uuid: 'agency-uuid',
          delegation_id: 'dlg_1',
          actor_issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
          application_url: nil,
          unique_session_id: 'session-hash',
          remembered: false,
        )
        %i[user_ip_address user_agent client_port device_id google_analytics_cookies].each do |key|
          expect(written.event_metadata).not_to have_key(key)
        end
        expect(delivered_events.map(&:event_type)).to eq(['delegated-access-consented'])
      end
    end
  end

  context 'when the recipient is listed without a usable encryption key' do
    let(:recipient) { create(:service_provider, :delegation_application, certs: []) }

    it 'treats the recipient as not enrolled and delivers nothing, without raising' do
      expect(writer.enabled?).to eq(false)
      expect(writer.forward(event)).to be_nil
      expect(writer.track_event('delegated-access-consented', remembered: false)).to be_nil
      expect(redis_client.read_events(issuer: recipient.issuer)).to be_empty
      expect(analytics).to have_logged_event(
        :delegated_access_attempts_delivery,
        hash_including(success: false, skipped_reason: 'recipient_not_enrolled'),
      )
    end
  end

  context 'when the recipient is not listed in the Attempts configuration' do
    let(:allowed_attempts_providers) { [] }

    it 'delivers nothing' do
      expect(writer.forward(event)).to be_nil
      expect(redis_client.read_events(issuer: recipient.issuer)).to be_empty
    end
  end

  context 'when delivery to agencies is switched off' do
    before do
      allow(IdentityConfig.store).to receive(:token_exchange_attempts_delivery_enabled)
        .and_return(false)
    end

    it 'delivers nothing and says why' do
      expect(writer.track_event('delegated-access-consented', remembered: false)).to be_nil
      expect(redis_client.read_events(issuer: recipient.issuer)).to be_empty
      expect(analytics).to have_logged_event(
        :delegated_access_attempts_delivery,
        hash_including(success: false, skipped_reason: 'delivery_disabled'),
      )
    end
  end

  context 'when writing fails' do
    before do
      allow(AttemptsApi::RedisClient).to receive(:new)
        .and_return(instance_double(AttemptsApi::RedisClient).tap do |client|
          allow(client).to receive(:write_event).and_raise(Redis::CannotConnectError)
        end)
    end

    it 'reports the error and returns nothing rather than raising' do
      expect(NewRelic::Agent).to receive(:notice_error).with(
        kind_of(Redis::CannotConnectError),
        custom_params: { recipient_issuer: recipient.issuer, event_type: 'login-completed' },
      )

      expect(writer.forward(event)).to be_nil
      expect(analytics).to have_logged_event(
        :delegated_access_attempts_delivery,
        hash_including(success: false, exception: 'Redis::CannotConnectError'),
      )
    end
  end
end
