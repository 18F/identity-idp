require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      browser_name: nil,
      browser_version: nil,
      browser_platform_name: nil,
      browser_platform_version: nil,
      browser_device_name: nil,
      browser_device_type: nil,
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
        new_event: true,
        path: path,
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
        new_event: nil,
        path: path,
      }

      expect(ahoy).to receive(:track).
          with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', { success: false })
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics_hash = {
        event_properties: {},
        user_id: tracked_user.uuid,
        locale: I18n.locale,
        git_sha: IdentityConfig::GIT_SHA,
        git_branch: IdentityConfig::GIT_BRANCH,
        new_session_path: true,
        new_event: true,
        path: path,
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

    it 'uses the DeviceDetector gem to parse the user agent' do
      user = build_stubbed(:user, uuid: '123')
      analytics = Analytics.new(
        user: user,
        request: FakeRequest.new,
        sp: nil,
        session: {},
        ahoy: ahoy,
      )

      browser = instance_double(DeviceDetector)
      allow(DeviceDetector).to receive(:new).and_return(browser)

      expect(ahoy).to receive(:track)
      expect(browser).to receive(:name)
      expect(browser).to receive(:full_version)
      expect(browser).to receive(:os_name)
      expect(browser).to receive(:os_full_version)
      expect(browser).to receive(:device_name)
      expect(browser).to receive(:device_type)
      expect(browser).to receive(:bot?)

      analytics.track_event('Trackable Event')
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
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end
  end
end
