require 'rails_helper'

describe Analytics do
  let(:request_attributes) do
    {
      user_agent: FakeRequest.new.user_agent,
      user_ip: FakeRequest.new.remote_ip
    }
  end

  let(:ahoy) { instance_double(FakeAhoyTracker) }

  before { allow(FakeAhoyTracker).to receive(:new).and_return(ahoy) }

  describe '#track_event' do
    it 'identifies the user and sends the event to the backend' do
      user = build_stubbed(:user, uuid: '123')

      analytics = Analytics.new(user, FakeRequest.new)

      expect(ahoy).to receive(:track).
        with('Trackable Event', request_attributes.merge(user_id: user.uuid))

      expect(Rails.logger).to receive(:info).with("Trackable Event: #{{ user_id: user.uuid }}")

      analytics.track_event('Trackable Event')
    end

    it 'tracks the user passed in to the track_event method' do
      current_user = build_stubbed(:user, uuid: '123')
      tracked_user = build_stubbed(:user, uuid: '456')

      analytics = Analytics.new(current_user, FakeRequest.new)

      expect(ahoy).to receive(:track).
        with('Trackable Event', request_attributes.merge(user_id: tracked_user.uuid))

      expect(Rails.logger).to receive(:info).
        with("Trackable Event: #{{ user_id: tracked_user.uuid }}")

      analytics.track_event('Trackable Event', user_id: tracked_user.uuid)
    end
  end

  describe '#track_event with DB storage' do
    it 'uses Ahoy::Stores::ActiveRecordTokenStore as the Ahoy::Store' do
      expect(Ahoy::Store.superclass).to eq Ahoy::Stores::ActiveRecordTokenStore
    end

    it 'stores events in the DB' do
      user = create(:user, uuid: '123')
      analytics = Analytics.new(user, FakeRequest.new)
      analytics.ahoy = Ahoy::Tracker.new(request: FakeRequest.new)

      analytics.track_event(:test_event)

      last_event_attributes = user.reload.ahoy_events.last.attributes
      properties = {
        'user_id' => user.uuid,
        'user_ip' => '127.0.0.1',
        'user_agent' => FakeRequest.new.user_agent
      }

      expect(last_event_attributes.keys).
        to eq %w(id name properties user_id created_at updated_at)
      expect(last_event_attributes['name']).to eq 'test_event'
      expect(last_event_attributes['properties']).to eq properties
      expect(last_event_attributes['user_id']).to eq user.id
    end
  end
end
