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

  describe '#grab_ga_client_id' do
    it 'returns nil if there is not a ga cookie' do
      user = build_stubbed(:user, uuid: '123')
      request = FakeRequest.new
      allow(request).to receive(:cookies).and_return({})
      analytics = Analytics.new(
        user: user,
        request: request,
        sp: 'http://localhost:3000',
        ahoy: ahoy,
      )

      client_id = analytics.grab_ga_client_id

      expect(client_id).to be_nil
    end

    it 'returns nil if there is a ga cookie but is not formatted properly ' do
      user = build_stubbed(:user, uuid: '123')
      request = FakeRequest.new
      allow(request).to receive(:cookies).and_return(_ga: 'GA1.4.33333A3333.2!!!!!#$$%')
      analytics = Analytics.new(
        user: user,
        request: request,
        sp: 'http://localhost:3000',
        ahoy: ahoy,
      )
      client_id = analytics.grab_ga_client_id

      expect(client_id).to be_nil
    end

    it 'returns a ga_client_id string if there is a valid cookie' do
      user = build_stubbed(:user, uuid: '123')
      request = FakeRequest.new
      allow(request).to receive(:cookies).and_return(_ga: 'GA1.4.3333333333.1142002911')

      analytics = Analytics.new(
        user: user,
        request: request,
        sp: 'http://localhost:3000',
        ahoy: ahoy,
      )

      client_id = analytics.grab_ga_client_id

      expect(client_id).to eq '3333333333.1142002911'
    end
  end
end
