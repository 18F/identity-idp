# frozen_string_literal: true

module FraudOpsApi
  class RedisClient < AttemptsApi::RedisClient
    attr_reader :redis_pool
    def initialize
      @redis_pool = REDIS_FRAUDOPS_POOL
    end

    private

    def hourly_keys(issuer)
      @redis_pool.with do |client|
        client.keys('fraudops-events:*')
      end.sort
    end

    def key(timestamp, issuer)
      formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
      "fraudops-events:#{sanitize(formatted_time)}"
    end

    def sanitize(key_string)
      key_string.tr(':', '-')
    end

    def event_ttl_seconds
      IdentityConfig.store.fraudops_event_ttl_seconds
    end
  end
end
