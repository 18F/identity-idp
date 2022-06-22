require 'rails_helper'

RSpec.describe IrsAttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(
      irs_attempt_api_enabled,
    )
  end

  let(:irs_attempt_api_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }

  subject { described_class.new(session_id: session_id, enabled_for_session: enabled_for_session) }

  describe '#track_event' do
    it 'records the event in redis' do
      subject.track_event(:test_event, foo: :bar)

      events = IrsAttemptsApi::RedisClient.new.read_events

      expect(events.values.length).to eq(1)
    end

    context 'the current session is not an IRS attempt API session' do
      let(:enabled_for_session) { false }

      it 'does not record any events in redis' do
        subject.track_event(:test_event, foo: :bar)

        events = IrsAttemptsApi::RedisClient.new.read_events

        expect(events.values.length).to eq(0)
      end
    end

    context 'the IRS attempts API is not enabled' do
      let(:irs_attempt_api_enabled) { false }

      it 'does not record any events in redis' do
        subject.track_event(:test_event, foo: :bar)

        events = IrsAttemptsApi::RedisClient.new.read_events

        expect(events.values.length).to eq(0)
      end
    end
  end
end
