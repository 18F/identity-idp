require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      host: FakeRequest.new.host
    }
  end

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)

      analytics_hash = {
        event: 'Trackable Event',
        properties: {},
        user_id: user.uuid
      }

      expect(ANALYTICS_LOGGER).to receive(:info).
        with(analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)

      analytics_hash = {
        event: 'Trackable Event',
        properties: {},
        user_id: tracked_user.uuid
      }

      expect(ANALYTICS_LOGGER).to receive(:info).
        with(analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end
  end
end
