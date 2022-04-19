require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      browser_name: 'Unknown Browser',
      browser_version: '0.0',
      browser_platform_name: 'Unknown',
      browser_platform_version: '0',
      browser_device_name: 'Unknown',
      browser_mobile: false,
      browser_bot: false,
      hostname: FakeRequest.new.host,
      pid: Process.pid,
      service_provider: 'http://localhost:3000',
      trace_id: nil,
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }
  let(:current_user) { build_stubbed(:user, uuid: '123') }
  let(:request) { FakeRequest.new }
  let(:path) { 'fake_path' }
  let(:success_state) { 'GET|fake_path|Trackable Event' }

  subject(:analytics) do
    Analytics.new(
      user: current_user,
      request: request,
      sp: 'http://localhost:3000',
      session: {},
      ahoy: ahoy,
    )
  end

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      stub_const(
        'IdentityConfig::GIT_BRANCH',
        'my branch',
      )

      analytics_hash = {
        event_properties: {},
        user_id: current_user.uuid,
        locale: I18n.locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_path: true,
        new_session_success_state: true,
        success_state: success_state,
        new_event: true,
        path: path,
        session_duration: nil,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end

    it 'does not track unique events and paths when an event fails' do
      analytics_hash = {
        event_properties: { success: false },
        user_id: current_user.uuid,
        locale: I18n.locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_path: nil,
        new_session_success_state: nil,
        success_state: success_state,
        new_event: nil,
        path: path,
        session_duration: nil,
      }

      expect(ahoy).to receive(:track).
          with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', { success: false })
    end

    it 'tracks the user passed in to the track_event method' do
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics_hash = {
        event_properties: {},
        user_id: tracked_user.uuid,
        locale: I18n.locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_success_state: true,
        success_state: success_state,
        new_session_path: true,
        new_event: true,
        path: path,
        session_duration: nil,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end

    context 'tracing headers' do
      let(:amazon_trace_id) { SecureRandom.hex }
      let(:request) do
        FakeRequest.new(headers: { 'X-Amzn-Trace-Id' => amazon_trace_id })
      end

      it 'includes the tracing header as trace_id' do
        expect(ahoy).to receive(:track).
          with('Trackable Event', hash_including(trace_id: amazon_trace_id))

        analytics.track_event('Trackable Event')
      end
    end

    it 'includes the locale of the current request' do
      locale = :fr
      allow(I18n).to receive(:locale).and_return(locale)

      analytics_hash = {
        event_properties: {},
        user_id: current_user.uuid,
        locale: locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_path: true,
        new_event: true,
        path: path,
        new_session_success_state: true,
        success_state: success_state,
        session_duration: nil,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end

    # relies on prepending the FakeAnalytics::PiiAlerter mixin
    it 'throws an error when pii is passed in' do
      allow(ahoy).to receive(:track)

      expect { analytics.track_event('Trackable Event') }.to_not raise_error

      expect { analytics.track_event('Trackable Event', first_name: 'Bobby') }.
        to raise_error(FakeAnalytics::PiiDetected)

      expect do
        analytics.track_event('Trackable Event', nested: [{ value: { first_name: 'Bobby' } }])
      end.to raise_error(FakeAnalytics::PiiDetected)

      expect { analytics.track_event('Trackable Event', decrypted_pii: '{"first_name":"Bobby"}') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end

    it 'throws an error when it detects sample PII in the payload' do
      allow(ahoy).to receive(:track)

      expect { analytics.track_event('Trackable Event', some_benign_key: 'FAKEY MCFAKERSON') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end

    it 'does not alert when pii_like_keypaths is passed' do
      allow(ahoy).to receive(:track) do |_name, attributes|
        # does not forward :pii_like_keypaths
        expect(attributes.to_s).to_not include('pii_like_keypaths')
      end

      expect do
        analytics.track_event(
          'Trackable Event',
          mfa_method_counts: { phone: 1 },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        )
      end.to_not raise_error
    end

    it 'does not alert when pii values are inside words' do
      expect(ahoy).to receive(:track)

      stub_const('DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC', zipcode: '12345')

      expect do
        analytics.track_event(
          'Trackable Event',
          some_uuid: '12345678-1234-1234-1234-123456789012',
        )
      end.to_not raise_error
    end
  end

  it 'tracks session duration' do
    freeze_time do
      analytics = Analytics.new(
        user: current_user,
        request: request,
        sp: 'http://localhost:3000',
        session: { session_started_at: 7.seconds.ago },
        ahoy: ahoy,
      )

      analytics_hash = {
        event_properties: {},
        user_id: current_user.uuid,
        locale: I18n.locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_success_state: true,
        success_state: success_state,
        new_session_path: true,
        new_event: true,
        path: path,
        session_duration: 7.0,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end
  end
end
