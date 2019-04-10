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
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }

  before { allow(FakeAhoyTracker).to receive(:new).and_return(ahoy) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(
        user: user,
        request: FakeRequest.new,
        sp: 'http://localhost:3000',
        ahoy: ahoy,
      )

      analytics_hash = {
        event_properties: {},
        user_id: user.uuid,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(
        user: current_user,
        request: FakeRequest.new,
        sp: 'http://localhost:3000',
        ahoy: ahoy,
      )

      analytics_hash = {
        event_properties: {},
        user_id: tracked_user.uuid,
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end

    it 'uses the DeviceDetector gem to parse the user agent' do
      user = build_stubbed(:user, uuid: '123')
      analytics = Analytics.new(user: user, request: FakeRequest.new, sp: nil, ahoy: ahoy)

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
  end
end
