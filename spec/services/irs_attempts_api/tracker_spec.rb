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

      events = IrsAttemptsApi::RedisClient.new.read_events

      expect(events.values.length).to eq(1)
    end
  end
end
