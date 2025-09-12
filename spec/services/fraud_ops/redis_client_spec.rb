require 'rails_helper'

RSpec.describe FraudOps::RedisClient do
  subject(:redis_client) { FraudOps::RedisClient.new }

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_event_ttl_seconds).and_return(604800)

    REDIS_FRAUD_OPS_POOL.with do |client|
      client.keys('fraud-ops-events:*').each { |key| client.del(key) }
    end
  end

  describe '#write_event' do
    it 'writes a JWE token to Redis with expiration' do
      event_key = SecureRandom.uuid
      jwe_token = 'eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZHQ00ifQ.test-jwe-token'
      timestamp = Time.zone.now

      redis_client.write_event(
        event_key: event_key,
        jwe: jwe_token,
        timestamp: timestamp,
      )

      REDIS_FRAUD_OPS_POOL.with do |client|
        hourly_key = "fraud-ops-events:#{timestamp.in_time_zone('UTC').change(
          min: 0,
          sec: 0,
        ).iso8601}"
        stored_data = client.hget(hourly_key, event_key)
        expect(stored_data).to eq(jwe_token)

        ttl = client.ttl(hourly_key)
        expect(ttl).to be > 0
        expect(ttl).to be <= 604800
      end
    end
  end

  describe '#read_all_events' do
    before do
      3.times do |i|
        redis_client.write_event(
          event_key: "test-event-#{i}",
          jwe: "test-jwe-token-#{i}",
          timestamp: Time.zone.now,
        )
      end
    end

    it 'reads all JWE tokens from Redis' do
      events = redis_client.read_all_events

      expect(events.keys).to include('test-event-0', 'test-event-1', 'test-event-2')
      expect(events['test-event-0']).to eq('test-jwe-token-0')
    end

    it 'respects batch size' do
      events = redis_client.read_all_events(batch_size: 2)

      expect(events.keys.count).to eq(2)
    end
  end

  describe '#delete_events' do
    before do
      redis_client.write_event(
        event_key: 'delete-me',
        jwe: 'test-jwe-token',
        timestamp: Time.zone.now,
      )
      redis_client.write_event(
        event_key: 'keep-me',
        jwe: 'test-jwe-token',
        timestamp: Time.zone.now,
      )
    end

    it 'deletes specified events' do
      deleted_count = redis_client.delete_events(keys: ['delete-me'])

      expect(deleted_count).to eq(1)

      remaining_events = redis_client.read_all_events
      expect(remaining_events.keys).to include('keep-me')
      expect(remaining_events.keys).not_to include('delete-me')
    end

    it 'returns 0 for empty keys array' do
      deleted_count = redis_client.delete_events(keys: [])
      expect(deleted_count).to eq(0)
    end
  end
end
