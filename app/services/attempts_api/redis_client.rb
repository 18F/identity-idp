# frozen_string_literal: true

module AttemptsApi
  class RedisClient
    def write_event(event_key:, jwe:, timestamp:, issuer:)
      key = key(timestamp, issuer)
      REDIS_ATTEMPTS_API_POOL.with do |client|
        client.hset(key, event_key, jwe)
        client.expire(key, IdentityConfig.store.attempts_api_event_ttl_seconds)
      end
    end

    def read_events(timestamp:, issuer:, batch_size: 5000)
      key = key(timestamp, issuer)
      events = {}
      REDIS_ATTEMPTS_API_POOL.with do |client|
        client.hscan_each(key, count: batch_size) do |k, v|
          events[k] = v
        end
      end
      events
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "attempts-api-events:#{issuer}:#{formatted_time}"
    end
  end
end
