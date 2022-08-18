require 'rails_helper'

describe IrsAttemptsApi::RedisClient do
  describe '#write_event' do
    it 'writes the attempt data to redis with the JTI as the key' do
      freeze_time do
        now = Time.zone.now
        event = IrsAttemptsApi::AttemptEvent.new(
          event_type: 'test_event',
          session_id: 'test-session-id',
          occurred_at: Time.zone.now,
          event_metadata: { 'foo' => 'bar' },
        )
        jti = event.jti
        jwe = event.to_jwe

        subject.write_event(jti: jti, jwe: jwe, timestamp: now)

        result = subject.redis_pool.with do |client|
          client.hget(subject.key(now), jti)
        end
        expect(result).to eq(jwe)
      end
    end
  end

  describe '#read_events' do
    it 'reads the event events from redis' do
      freeze_time do
        now = Time.zone.now
        events = {}
        3.times do
          event = IrsAttemptsApi::AttemptEvent.new(
            event_type: 'test_event',
            session_id: 'test-session-id',
            occurred_at: now,
            event_metadata: { 'foo' => 'bar' },
          )
          jti = event.jti
          jwe = event.to_jwe
          events[jti] = jwe
        end
        events.each do |jti, jwe|
          subject.write_event(jti: jti, jwe: jwe, timestamp: now)
        end

        result = subject.read_events(timestamp: now)

        expect(result).to eq(events)
      end
    end

    it 'stores events in hourly buckets' do
      time1 = Time.new(2022, 1, 1, 1, 0, 0, 'Z')
      time2 = Time.new(2022, 1, 1, 2, 0, 0, 'Z')
      event1 = IrsAttemptsApi::AttemptEvent.new(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: time1,
        event_metadata: { 'foo' => 'bar' },
      )
      event2 = IrsAttemptsApi::AttemptEvent.new(
        event_type: 'test_event',
        session_id: 'test-session-id',
        occurred_at: time2,
        event_metadata: { 'foo' => 'bar' },
      )
      jwe1 = event1.to_jwe
      jwe2 = event2.to_jwe

      subject.write_event(jti: event1.jti, jwe: jwe1, timestamp: event1.occurred_at)
      subject.write_event(jti: event2.jti, jwe: jwe2, timestamp: event2.occurred_at)

      expect(subject.read_events(timestamp: time1)).to eq({ event1.jti => jwe1 })
      expect(subject.read_events(timestamp: time2)).to eq({ event2.jti => jwe2 })
    end
  end
end
