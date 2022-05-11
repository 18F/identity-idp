# This class is similar to RedisRateLimiter, but differs in that
# the throttle period begins once the maximum number of allowed
# attempts has been reached.
class RedisThrottle
  attr_reader :throttle_type

  VALID_THROTTLE_TYPES = %i[
    idv_doc_auth reg_unconfirmed_email reg_confirmed_email reset_password_email idv_resolution
    idv_send_link verify_personal_key verify_gpo_key proof_ssn proof_address phone_confirmation
  ]
  THROTTLE_CONFIG = {
    idv_doc_auth: {
      max_attempts: IdentityConfig.store.doc_auth_max_attempts,
      attempt_window: IdentityConfig.store.doc_auth_attempt_window_in_minutes,
    },
    reg_unconfirmed_email: {
      max_attempts: IdentityConfig.store.reg_unconfirmed_email_max_attempts,
      attempt_window: IdentityConfig.store.reg_unconfirmed_email_window_in_minutes,
    },
    reg_confirmed_email: {
      max_attempts: IdentityConfig.store.reg_confirmed_email_max_attempts,
      attempt_window: IdentityConfig.store.reg_confirmed_email_window_in_minutes,
    },
    reset_password_email: {
      max_attempts: IdentityConfig.store.reset_password_email_max_attempts,
      attempt_window: IdentityConfig.store.reset_password_email_window_in_minutes,
    },
    idv_resolution: {
      max_attempts: IdentityConfig.store.idv_max_attempts,
      attempt_window: IdentityConfig.store.idv_attempt_window_in_hours * 60,
    },
    idv_send_link: {
      max_attempts: IdentityConfig.store.idv_send_link_max_attempts,
      attempt_window: IdentityConfig.store.idv_send_link_attempt_window_in_minutes,
    },
    verify_personal_key: {
      max_attempts: IdentityConfig.store.verify_personal_key_max_attempts,
      attempt_window: IdentityConfig.store.verify_personal_key_attempt_window_in_minutes,
    },
    verify_gpo_key: {
      max_attempts: IdentityConfig.store.verify_gpo_key_max_attempts,
      attempt_window: IdentityConfig.store.verify_gpo_key_attempt_window_in_minutes,
    },
    proof_ssn: {
      max_attempts: IdentityConfig.store.proof_ssn_max_attempts,
      attempt_window: IdentityConfig.store.proof_ssn_max_attempt_window_in_minutes,
    },
    proof_address: {
      max_attempts: IdentityConfig.store.proof_address_max_attempts,
      attempt_window: IdentityConfig.store.proof_address_max_attempt_window_in_minutes,
    },
    phone_confirmation: {
      max_attempts: IdentityConfig.store.phone_confirmation_max_attempts,
      attempt_window: IdentityConfig.store.phone_confirmation_max_attempt_window_in_minutes,
    },
  }.with_indifferent_access.freeze

  def initialize(throttle_type:, user: nil, target: nil)
    @throttle_type = throttle_type
    @user = user
    @target = target

    unless VALID_THROTTLE_TYPES.include?(throttle_type)
      raise ArgumentError,
            'throttle_type is not valid'
    end
    if @user.blank? && @target.blank?
      raise ArgumentError, 'RedisThrottle must have a user or a target, but neither were provided'
    end

    if @user.present? && @target.present?
      raise ArgumentError, 'RedisThrottle must have a user or a target, but both were provided'
    end

    if target && !target.is_a?(String)
      raise ArgumentError,
            "target must be a string, but got #{target.class}"
    end
  end

  def attempts
    if IdentityConfig.store.redis_throttle_enabled
      @redis_attempts.to_i
    else
      postgres_throttle.attempts
    end
  end

  def throttled?
    if IdentityConfig.store.redis_throttle_enabled
      !expired? && maxed?
    else
      postgres_throttle.throttled?
    end
  end

  def throttled_else_increment?
    if throttled?
      true
    else
      increment!
      false
    end
  end

  def attempted_at
    if IdentityConfig.store.redis_throttle_enabled
      redis_attempted_at
    else
      postgres_throttle.attempted_at
    end
  end

  def expires_at
    if IdentityConfig.store.redis_throttle_enabled
      return Time.zone.now if redis_attempted_at.blank?
      redis_attempted_at + RedisThrottle.attempt_window_in_minutes(throttle_type).minutes
    else
      postgres_throttle.expires_at
    end
  end

  def remaining_count
    return 0 if throttled?

    if IdentityConfig.store.redis_throttle_enabled
      RedisThrottle.max_attempts(throttle_type) - attempts
    else
      postgres_throttle.remaining_count
    end
  end

  def redis_attempts
    return @redis_attempts if defined?(@redis_attempts)

    fetch_state!

    @redis_attempts
  end

  def redis_attempted_at
    return @redis_attempted_at if defined?(@redis_attempted_at)

    fetch_state!

    @redis_attempted_at
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def maxed?
    @redis_attempts && @redis_attempts >= RedisThrottle.max_attempts(throttle_type)
  end

  def increment!
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.incr(key)
        multi.expire(
          key,
          RedisThrottle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i,
        )
      end
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = Time.zone.now

    postgres_throttle.increment

    attempts
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

    @redis_attempts = value.to_i

    if ttl < 0
      @redis_attempted_at = nil
    else
      @redis_attempted_at =
        Time.zone.now +
        RedisThrottle.attempt_window_in_minutes(throttle_type).minutes - ttl.seconds
    end

    self
  end

  def reset!
    REDIS_THROTTLE_POOL.with do |client|
      client.del(key)
    end

    postgres_throttle.reset

    @redis_attempts = 0
    @redis_attempted_at = nil
  end

  def set_as_throttled!
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.set(key, RedisThrottle.max_attempts(throttle_type))
        multi.expire(
          key,
          RedisThrottle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i,
        )
      end
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = Time.zone.now

    postgres_throttle.update(
      attempts: RedisThrottle.max_attempts(throttle_type),
      attempted_at: Time.zone.now,
    )

    attempts
  end

  def key
    if @user_id
      "throttle:#{@user_id}:#{throttle_type}"
    else
      "throttle:#{@target}:#{throttle_type}"
    end
  end

  def postgres_throttle
    return @postgres_throttle if @postgres_throttle

    @postgres_throttle ||= Throttle.for(throttle_type: throttle_type, user: @user, target: @target)
  end

  def self.attempt_window_in_minutes(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :attempt_window)
  end

  def self.max_attempts(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :max_attempts)
  end
end
