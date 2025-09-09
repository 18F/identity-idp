# frozen_string_literal: true

class FraudOpsRedisClient
  def write_event(event_key:, encrypted_data:, timestamp:)
    key = hourly_key(timestamp)
    REDIS_FRAUD_OPS_POOL.with do |client|
      client.hset(key, event_key, encrypted_data)
      client.expire(key, IdentityConfig.store.fraud_ops_event_ttl_seconds)
    end
  end

  def read_all_events(batch_size: 1000)
    events = {}
    all_hourly_keys.each do |hourly_key|
      REDIS_FRAUD_OPS_POOL.with do |client|
        client.hscan_each(hourly_key, count: batch_size) do |k, v|
          break if events.keys.count >= batch_size

          events[k] = v
        end
      end
      break if events.keys.count >= batch_size
    end
    events
  end

  def delete_events(keys:)
    return 0 if keys.blank?

    total_deleted = 0
    all_hourly_keys.each do |hourly_key|
      REDIS_FRAUD_OPS_POOL.with do |client|
        deleted = client.hdel(hourly_key, *keys)
        total_deleted += deleted if deleted > 0
      end
    end

    total_deleted
  end

  def clear_expired_keys
    expired_keys = []
    cutoff_time = IdentityConfig.store.fraud_ops_event_ttl_seconds.seconds.ago

    REDIS_FRAUD_OPS_POOL.with do |client|
      all_hourly_keys.each do |key|
        ttl = client.ttl(key)
        if ttl == -1 || ttl == -2
          expired_keys << key
        else
          timestamp_str = key.split(':').last
          begin
            key_time = Time.parse(timestamp_str)
            expired_keys << key if key_time < cutoff_time
          rescue ArgumentError
            expired_keys << key
          end
        end
      end

      expired_keys.each { |key| client.del(key) } if expired_keys.any?
    end

    expired_keys.length
  end

  private

  def hourly_key(timestamp)
    formatted_time = timestamp.in_time_zone('UTC').change(min: 0, sec: 0).iso8601
    "fraud-ops-events:#{formatted_time}"
  end

  def all_hourly_keys
    REDIS_FRAUD_OPS_POOL.with do |client|
      client.keys('fraud-ops-events:*')
    end.sort
  end
end
