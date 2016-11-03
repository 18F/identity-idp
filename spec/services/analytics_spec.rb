require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_agent: FakeRequest.new.user_agent,
      user_ip: FakeRequest.new.remote_ip
    }
  end

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)

      expect(FakeKeen).to receive(:perform_later).
        with('Trackable Event', request_attributes.merge(user_id: user.uuid))

      expect(Rails.logger).to receive(:info).with("Trackable Event: #{{ user_id: user.uuid }}")

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)

      expect(FakeKeen).to receive(:perform_later).
        with('Trackable Event', request_attributes.merge(user_id: tracked_user.uuid))

      expect(Rails.logger).to receive(:info).
        with("Trackable Event: #{{ user_id: tracked_user.uuid }}")

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end
  end
end
