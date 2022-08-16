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

    def write_event(jti:, jwe:)
      redis_pool.with do |client|
        client.setex(jti, IdentityConfig.store.irs_attempt_api_event_ttl_seconds, jwe)
      end
    end

    def delete_events(event_ids)
      redis_pool.with do |client|
        client.del(*event_ids)
      end
    end

    def read_events(count = 1000)
      redis_pool.with do |client|
        keys = client.scan(0, count: count).last.first(count)
        next {} if keys.empty?
        client.mapped_mget(*keys)
      end
    end

    def self.clear_attempts!
      unless %w[test development].include?(Rails.env)
        raise 'RedisClient.clear_attempts! should not be called outside of dev or test!'
      end
      Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url).flushall
    end
  end
end
