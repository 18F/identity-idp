require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_agent: FakeRequest.new.user_agent,
      user_ip: FakeRequest.new.remote_ip
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }

  let(:google_analytics_options) { request_attributes.merge(anonymize_ip: true) }

  before { allow(FakeAhoyTracker).to receive(:new).and_return(ahoy) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(google_analytics_options.merge(action: 'Trackable Event', user_id: user.uuid))

      expect(ahoy).to receive(:track).
        with('Trackable Event', request_attributes.merge(user_id: user.uuid))

      expect(Rails.logger).to receive(:info).with("Trackable Event by #{user.uuid}")

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(google_analytics_options.merge(user_id: tracked_user.uuid, action: 'Trackable Event'))

      expect(ahoy).to receive(:track).
        with('Trackable Event', request_attributes.merge(user_id: tracked_user.uuid))

      expect(Rails.logger).to receive(:info).with("Trackable Event by #{tracked_user.uuid}")

      analytics.track_event('Trackable Event', tracked_user)
    end
  end

  describe '#track_anonymous_event' do
    it 'sends the event and attribute value' do
      analytics = Analytics.new(nil, FakeRequest.new)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(google_analytics_options.merge(action: 'Anonymous Event', value: 'foo'))

      expect(ahoy).to receive(:track).
        with('Anonymous Event', request_attributes.merge(value: 'foo'))

      expect(Rails.logger).to receive(:info).with('Anonymous Event: foo')

      analytics.track_anonymous_event('Anonymous Event', 'foo')
    end
  end

  describe '#track_pageview' do
    it 'logs the pageview' do
      analytics = Analytics.new(nil, FakeRequest.new)

      expect(ahoy).to receive(:track_visit)

      analytics.track_pageview
    end
  end
end
