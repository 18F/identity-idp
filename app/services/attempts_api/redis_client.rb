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

    def write_many_events(event_key:, jwe:, timestamp:, issuer:, count: 100)
      key = key(timestamp, issuer)

      REDIS_ATTEMPTS_API_POOL.with do |client|
        client.pipelined do |pipeline|
          count.times do
            client.hset(key, SecureRandom.uuid, jwe)
          end
          client.expire(key, IdentityConfig.store.attempts_api_event_ttl_seconds)
        end
      end
    end

    def read_events(issuer:, batch_size: 1000)
      events = {}
      hourly_keys(issuer).each do |hourly_key|
        REDIS_ATTEMPTS_API_POOL.with do |client|
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
        REDIS_ATTEMPTS_API_POOL.with do |client|
          total_deleted += client.hdel(hourly_key, keys)
        end
      end

      total_deleted
    end

    private

    def hourly_keys(issuer)
      REDIS_ATTEMPTS_API_POOL.with do |client|
        client.keys("attempts-api-events:#{issuer}:*")
      end.sort
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "attempts-api-events:#{issuer}:#{formatted_time}"
    end
  end
end
