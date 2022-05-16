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

    def write_event(event_data)
      key = event_data.jti
      redis_pool.with do |client|
        client.set(key, event_data.to_json)
        client.expire(key, IdentityConfig.store.irs_attempt_api_event_ttl_seconds)
      end
    end

    def delete_events(event_ids)
      redis_pool.with do |client|
        client.del(*event_ids)
      end
    end

    def read_events(count = 1000)
      redis_pool.with do |client|
        keys = client.scan(0, count: count).last
        client.mapped_mget(*keys).transform_values do |event_data|
          next unless event_data.present?
          IrsAttemptsApi::Event.from_json(event_data)
        end.values.compact
      end
    end

    def self.clear_attempts!
      if !Rails.env.test?
        raise 'IrsAttemptsApi::RedisClient.clear_attempts! should not be called outside of test env'
      end
      Redis.new(url: IdentityConfig.store.redis_irs_attempt_api_url).flushall
    end
  end
end
