require 'rails_helper'

RSpec.describe IrsAttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(
      irs_attempt_api_enabled,
    )
    allow(request).to receive(:user_agent).and_return('example/1.0')
    allow(request).to receive(:remote_ip).and_return('192.0.2.1')
    allow(request).to receive(:get_header).with('CloudFront-Viewer-Address').
      and_return('192.0.2.1:1234')
  end

  let(:irs_attempt_api_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:service_provider) { create(:service_provider) }
  let(:cookie_device_uuid) { 'device_id' }
  let(:sp_request_uri) { 'https://example.com/auth_page' }
  let(:user) { create(:user) }

  subject do
    described_class.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: service_provider,
      cookie_device_uuid: cookie_device_uuid,
      sp_request_uri: sp_request_uri,
      enabled_for_session: enabled_for_session,
    )
  end

  describe '#track_event' do
    it 'records the event in redis' do
      freeze_time do
        subject.track_event(:test_event, foo: :bar)

        events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

        expect(events.values.length).to eq(1)
      end
    end

    context 'the current session is not an IRS attempt API session' do
      let(:enabled_for_session) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

          expect(events.values.length).to eq(0)
        end
      end
    end

    context 'the IRS attempts API is not enabled' do
      let(:irs_attempt_api_enabled) { false }

      it 'does not record any events in redis' do
        freeze_time do
          subject.track_event(:test_event, foo: :bar)

          events = IrsAttemptsApi::RedisClient.new.read_events(timestamp: Time.zone.now)

          expect(events.values.length).to eq(0)
        end
      end
    end
  end
end
