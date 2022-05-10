# This class is similar to RedisRateLimiter, but differs in that
# the throttle period begins once the maximum number of allowed
# attempts has been reached.
class RedisThrottle
  attr_reader :throttle_type

  def initialize(throttle_type:, target:)
    @throttle_type = throttle_type
    @target = target
  end

  def attempts
    return @attempts if defined?(@attempts)

    fetch_state!

    @attempts
  end

  def attempted_at
    return @attempted_at if defined?(@attempted_at)

    fetch_state!

    @attempted_at
  end

  def increment!
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.incr(key)
        multi.expire(key, Throttle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i)
      end
    end

    @attempts = value.to_i
    @attempted_at = Time.zone.now
  end

  def fetch_state!
    value = nil
    ttl = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, ttl = client.multi do |multi|
        multi.get(key)
        multi.ttl(key)
      end
    end

    @attempts = value.to_i

    if ttl < 0
      @attempted_at = nil
    else
      @attempted_at = Time.zone.now +
                      Throttle.attempt_window_in_minutes(throttle_type).minutes - ttl.seconds
    end

    nil
  end

  def reset!
    REDIS_THROTTLE_POOL.with do |client|
      client.del(key)
    end

    @attempts = 0
    @attempted_at = nil
  end

  def key
    "throttle:#{@target}:#{@throttle_type}"
  end
end
