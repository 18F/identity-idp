require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_ip: FakeRequest.new.remote_ip,
      user_agent: FakeRequest.new.user_agent
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }

  let(:google_analytics_options) { request_attributes.merge(anonymize_ip: true) }

  before { allow(FakeAhoyTracker).to receive(:new).and_return(ahoy) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)
      consolidated_attributes = request_attributes.reverse_merge(user_id: user.uuid)

      expect(ahoy).to receive(:track).
        with('Trackable Event', consolidated_attributes)

      expect(Rails.logger).to receive(:info).
        with("Trackable Event: #{consolidated_attributes}")

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)
      consolidated_attributes = request_attributes.reverse_merge(user_id: tracked_user.uuid)

      expect(ahoy).to receive(:track).
        with('Trackable Event', consolidated_attributes)

      expect(Rails.logger).to receive(:info).
        with("Trackable Event: #{consolidated_attributes}")

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end
  end
end
