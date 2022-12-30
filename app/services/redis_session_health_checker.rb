# frozen_string_literal: true

module RedisSessionHealthChecker
  CACHE_KEY = 'redis_health_check'
  module_function

  # @return [HealthCheckSummary]
  def check
    HealthCheckSummary.new(healthy: health_write_and_read, result: {
      primary_redis: health_write_and_read
    })
  end

  # @api private
  def health_write_and_read
    MemoryCache.cache.fetch(CACHE_KEY, expires_in: 2.minutes, race_condition_ttl: 10.seconds) do
      value = "healthy at #{Time.now.iso8601}"
      read_value = REDIS_POOL.with do |client|
        client.setex(health_record_key, 3.minutes, value)
        client.get(health_record_key)
      end

      read_value == value
    end
  end

  # @api private
  def health_record_key
    "healthcheck_#{Socket.gethostname}"
  end
end
