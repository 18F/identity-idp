# frozen_string_literal: true

module FraudOps
  class RedisClient
    def write_event(event_key:, jwe:, timestamp:)
      key = five_minute_key(timestamp)
      REDIS_FRAUD_OPS_POOL.with do |client|
        client.hset(key, event_key, jwe)
        client.expire(key, IdentityConfig.store.fraud_ops_event_ttl_seconds)
      end
    end

    private

    def five_minute_key(timestamp)
      formatted_time = timestamp
        .in_time_zone('UTC')
        .change(min: (timestamp.min / 5) * 5)
        .iso8601
      "fraud-ops-events:#{formatted_time}"
    end
  end
end
