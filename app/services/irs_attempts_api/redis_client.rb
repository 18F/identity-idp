module IrsAttemptsApi
  class RedisClient
    cattr_accessor :redis_pool do
      ConnectionPool.new(size: IdentityConfig.store.redis_irs_attempt_api_pool_size) do
        Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url)
      end
    end

    def write_event(event_key:, jwe:, timestamp:)
      key = key(timestamp)
      redis_pool.with do |client|
        client.hset(key, event_key, jwe)
        client.expire(key, IdentityConfig.store.irs_attempt_api_event_ttl_seconds)
      end
    end

    def read_events(timestamp:, batch_size: 5000)
      key = key(timestamp)
      events = {}
      redis_pool.with do |client|
        client.hscan_each(key, count: batch_size) do |k, v|
          events[k] = v
        end
      end
      events
    end

    def remove_events(timestamp:)
      return unless IdentityConfig.store.irs_attempt_api_delete_events_after_s3_upload

      key = key(timestamp)
      redis_pool.with do |client|
        client.del(key)
      end
    end

    def key(timestamp)
      'irs-attempt-api:' + timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
    end

    def self.clear_attempts!
      unless %w[test development].include?(Rails.env)
        raise 'RedisClient.clear_attempts! should not be called outside of dev or test!'
      end
      Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url).flushall
    end
  end
end
