require 'rails_helper'

RSpec.describe IrsAttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
    IrsAttemptsApi::RedisClient.clear_attempts!
  end

  let(:session_id) { 'test-session-id' }

  subject { described_class.new(session_id: session_id) }

  describe '#track_event' do
    it 'records the event in redis' do
      subject.track_event(:test_event, foo: :bar)

      raw_events = IrsAttemptsApi::RedisClient.new.read_events

      expect(raw_events.length).to eq(1)
      raw_event = raw_events.first
      expect(raw_event.jti).to be_a(String)
      expect(Time.zone.at(raw_event.iat)).to be_within(1.second).of(Time.zone.now)
      expect(raw_event.event_type).to eq('test_event')
      expect(raw_event.encrypted_event_data).to be_a(String)
    end
  end
end
