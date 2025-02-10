# frozen_string_literal: true

# Implementation of https://redis.com/redis-best-practices/basic-rate-limiting/
class RedisRateLimiter
  class LimitError < StandardError; end

  attr_reader :key, :max_requests, :interval, :redis_pool

  # @param [String] key the item to throttle on
  # @param [Integer] max_requests the max number of requests allowed per interval
  # @param [Integer] interval number of seconds
  def initialize(key:, max_requests:, interval:, redis_pool: REDIS_THROTTLE_POOL)
    @key = key
    @max_requests = max_requests
    @interval = interval.to_i
    @redis_pool = redis_pool
  end

  # @yield a block to run if the limit has not been hit
  # @raise [LimitError] throws an error when the limit has been hit, and the
  #   block was not run
  def attempt!(now = Time.zone.now)
    raise LimitError, "rate limit for #{key} has maxed out" if maxed?(now)

    increment(now)

    yield
  end

  # @return [Boolean]
  def maxed?(now = Time.zone.now)
    redis_pool.with do |redis|
      redis.get(build_key(now)).to_i >= max_requests
    end
  end

  def increment(now = Time.zone.now)
    rate_limit_key = build_key(now)

    redis_pool.with do |redis|
      redis.multi do
        redis.incr(rate_limit_key)
        redis.expire(rate_limit_key, interval - 1)
      end
    end
  end

  # @api private
  # @return [String]
  def build_key(now)
    rounded_seconds = (now.to_i / interval) * interval
    "throttle:redis-rate-limiter:#{key}:#{rounded_seconds}"
  end
end
