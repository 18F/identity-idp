require 'rails_helper'

describe IrsAttemptsApi::RedisClient do
  describe '#write_event' do
    it 'writes the attempt data to redis with the JTI as the key' do
      event = IrsAttemptsApi::AttemptEvent.new(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: Time.zone.now,
        event_metadata: { 'foo' => 'bar' },
      )
      jti = event.jti
      jwe = event.to_jwe

      subject.write_event(jti: jti, jwe: jwe)

      result = subject.redis_pool.with do |client|
        client.get(jti)
      end
      expect(result).to eq(jwe)
    end
  end

  describe '#read_events' do
    it 'reads the event events from redis' do
      events = {}
      3.times do
        event = IrsAttemptsApi::AttemptEvent.new(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.zone.now,
          event_metadata: { 'foo' => 'bar' },
        )
        jti = event.jti
        jwe = event.to_jwe
        events[jti] = jwe
      end
      events.each do |jti, jwe|
        subject.write_event(jti: jti, jwe: jwe)
      end

      result = subject.read_events

      expect(result).to eq(events)
    end
  end

  describe '#delete_events' do
    it 'deletes the events from redis' do
      events = {}
      3.times do
        event = IrsAttemptsApi::AttemptEvent.new(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.zone.now,
          event_metadata: { 'foo' => 'bar' },
        )
        jti = event.jti
        events[jti] = event.to_jwe
      end
      events.each do |jti, jwe|
        subject.write_event(jti: jti, jwe: jwe)
      end

      subject.redis_pool.with do |client|
        expect(client.exists(*events.keys)).to eq(3)
      end

      subject.delete_events(events.keys)

      subject.redis_pool.with do |client|
        expect(client.exists(*events.keys)).to eq(0)
      end
    end
  end
end
