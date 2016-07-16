require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_agent: 'special_agent',
      user_ip: '127.0.0.1'
    }
  end

  let(:ahoy) { NullAhoyTracker.new }

  let(:common_options) { request_attributes.merge(anonymize_ip: true) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, request_attributes, ahoy)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(action: 'Trackable Event', user_id: user.uuid))
      expect(ahoy).to receive(:track).with('Trackable Event')
      expect(Rails.logger).to receive(:info).with("Trackable Event by #{user.uuid}")

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, request_attributes, ahoy)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(user_id: tracked_user.uuid, action: 'Trackable Event'))
      expect(ahoy).to receive(:track).with('Trackable Event')
      expect(Rails.logger).to receive(:info).with("Trackable Event by #{tracked_user.uuid}")

      analytics.track_event('Trackable Event', tracked_user)
    end
  end

  describe '#track_anonymous_event' do
    it 'sends the event and attribute value' do
      analytics = Analytics.new(nil, request_attributes, ahoy)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(action: 'Anonymous Event', value: 'foo'))
      expect(ahoy).to receive(:track).with('Anonymous Event', value: 'foo')
      expect(Rails.logger).to receive(:info).with('Anonymous Event: foo')

      analytics.track_anonymous_event('Anonymous Event', 'foo')
    end
  end

  describe '#track_pageview' do
    it 'logs the pageview' do
      analytics = Analytics.new(nil, request_attributes, ahoy)

      expect(ahoy).to receive(:track_visit)

      analytics.track_pageview
    end
  end
end
