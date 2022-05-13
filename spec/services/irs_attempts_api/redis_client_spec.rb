require 'rails_helper'

describe IrsAttemptsApi::RedisClient do
  before do
    IrsAttemptsApi::RedisClient.clear_attempts!
  end

  describe '#write_event' do
    it 'writes the attempt data to redis with the JTI as the key' do
      event = IrsAttemptsApi::Event.build(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: Time.now,
        event_metadata: { 'foo' => 'bar' }
      )

      subject.write_event(event)

      result = subject.redis_pool.with do |client|
        JSON.parse(client.get(event.jti))
      end
      expect(result).to eq(event.to_h.stringify_keys)
    end
  end

  describe '#read_events' do
    it 'reads the event events from redis' do
      events = []
      3.times do
        event = IrsAttemptsApi::Event.build(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.now,
          event_metadata: { 'foo' => 'bar' }
        )
        events.push(event)
      end
      events.each do |event|
        subject.write_event(event)
      end

      result = subject.read_events
      expect(result).to match_array(events)
    end
  end

  describe '#delete_events' do
    it 'deletes the events from redis' do
      events = []
      3.times do
        event = IrsAttemptsApi::Event.build(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.now,
          event_metadata: { 'foo' => 'bar' }
        )
        events.push(event)
      end
      events.each do |event|
        subject.write_event(event)
      end

      event_jtis = events.map(&:jti)

      subject.redis_pool.with do |client|
        expect(client.exists(*event_jtis)).to eq(3)
      end

      subject.delete_events(event_jtis)

      subject.redis_pool.with do |client|
        expect(client.exists(*event_jtis)).to eq(0)
      end
    end
  end
end
