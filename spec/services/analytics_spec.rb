require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_agent: 'special_agent',
      user_ip: '127.0.0.1'
    }
  end

  let(:common_options) { request_attributes.merge(anonymize_ip: true) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, request_attributes)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(action: 'Trackable Event', user_id: user.uuid))

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, request_attributes)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(user_id: tracked_user.uuid, action: 'Trackable Event'))

      analytics.track_event('Trackable Event', tracked_user)
    end
  end

  describe '#track_anonymous_event' do
    it 'sends the event and attribute value' do
      analytics = Analytics.new(nil, request_attributes)

      expect(AnalyticsEventJob).to receive(:perform_later).
        with(common_options.merge(action: 'Anonymous Event', value: 'foo'))

      analytics.track_anonymous_event('Anonymous Event', 'foo')
    end
  end
end
