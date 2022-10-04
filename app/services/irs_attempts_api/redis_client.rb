module IrsAttemptsApi
  class RedisClient
    cattr_accessor :redis_pool do
      ConnectionPool.new(size: 10) do
        Redis::Namespace.new(
          'irs-attempt-api',
          redis: Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url),
        )
      end
    end

    def write_event(event_key:, jwe:, timestamp:)
      key = key(timestamp)
      redis_pool.with do |client|
        client.hset(key, event_key, jwe)
        client.expire(key, IdentityConfig.store.irs_attempt_api_event_ttl_seconds)
      end
    end

    def read_events(timestamp:)
      key = key(timestamp)
      redis_pool.with do |client|
        # see client.hscan which refs https://redis.io/commands/scan/
        # but it's... a lil' bit weird.
        client.hgetall(key)
      end
    end

    def key(timestamp)
      timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
    end

    def self.clear_attempts!
      unless %w[test development].include?(Rails.env)
        raise 'RedisClient.clear_attempts! should not be called outside of dev or test!'
      end
      Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url).flushall
    end
  end
end
