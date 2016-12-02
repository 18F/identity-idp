require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent,
      host: FakeRequest.new.host
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }

  before { allow(FakeAhoyTracker).to receive(:new).and_return(ahoy) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)

      analytics_hash = {
        event_properties: {},
        user_id: user.uuid
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)

      analytics_hash = {
        event_properties: {},
        user_id: tracked_user.uuid
      }

      expect(ahoy).to receive(:track).
        with('Trackable Event', analytics_hash.merge(request_attributes))

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end

    context 'when google analytics key is present' do
      it 'calls google analytics job with event name' do
        user = build_stubbed(:user, uuid: '123')
        allow(Figaro.env).to receive(:google_analytics_key).and_return('foo')
        analytics = Analytics.new(user, FakeRequest.new)

        analytics_hash = {
          event_properties: {},
          user_id: user.uuid
        }

        expect(ahoy).to receive(:track).
          with('Trackable Event', analytics_hash.merge(request_attributes))

        expect(GoogleAnalyticsJob).to receive(:perform_later).with(event_name: 'Trackable Event')

        analytics.track_event('Trackable Event')
      end
    end

    context 'when google analytics key is not present' do
      it 'does not call google analytics job' do
        user = build_stubbed(:user, uuid: '123')
        analytics = Analytics.new(user, FakeRequest.new)

        analytics_hash = {
          event_properties: {},
          user_id: user.uuid
        }

        expect(ahoy).to receive(:track).
          with('Trackable Event', analytics_hash.merge(request_attributes))

        expect(GoogleAnalyticsJob).to_not receive(:perform_later)

        analytics.track_event('Trackable Event')
      end
    end
  end
end
