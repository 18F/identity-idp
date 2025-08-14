# frozen_string_literal: true

module AttemptsApi
  class RedisClient
    attr_reader :redis_pool
    def initialize(redis_pool = REDIS_ATTEMPTS_API_POOL)
      @redis_pool = redis_pool
    end

    def write_event(event_key:, jwe:, timestamp:, issuer:)
      key = key(timestamp, issuer)
      @redis_pool.with do |client|
        client.hset(key, event_key, jwe)
        client.expire(key, IdentityConfig.store.attempts_api_event_ttl_seconds)
      end
    end

    def read_events(issuer:, batch_size: 1000)
      events = {}
      hourly_keys(issuer).each do |hourly_key|
        @redis_pool.with do |client|
          client.hscan_each(hourly_key, count: batch_size) do |k, v|
            break if events.keys.count == batch_size

            events[k] = v
          end
        end
      end
      events
    end

    def delete_events(issuer:, keys:)
      total_deleted = 0
      hourly_keys(issuer).each do |hourly_key|
        @redis_pool.with do |client|
          total_deleted += client.hdel(hourly_key, keys)
        end
      end

      total_deleted
    end

    private

    def hourly_keys(issuer)
      @redis_pool.with do |client|
        client.keys("attempts-api-events:#{issuer}:*")
      end.sort
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "attempts-api-events:#{issuer}:#{formatted_time}"
    end
  end
end
