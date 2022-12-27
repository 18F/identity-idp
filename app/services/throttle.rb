# This class is similar to RedisRateLimiter, but differs in that
# the throttle period begins once the maximum number of allowed
# attempts has been reached.
class Throttle
  attr_reader :throttle_type

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
    inherited_proofing: {
      max_attempts: IdentityConfig.store.inherited_proofing_max_attempts,
      attempt_window: IdentityConfig.store.inherited_proofing_max_attempt_window_in_minutes,
    },
  }.with_indifferent_access.freeze

  def initialize(throttle_type:, user: nil, target: nil)
    @throttle_type = throttle_type
    @user = user
    @target = target

    unless THROTTLE_CONFIG.key?(throttle_type)
      raise ArgumentError,
            'throttle_type is not valid'
    end
    if @user.blank? && @target.blank?
      raise ArgumentError, 'Throttle must have a user or a target, but neither were provided'
    end

    if @user.present? && @target.present?
      raise ArgumentError, 'Throttle must have a user or a target, but both were provided'
    end

    if target && !target.is_a?(String)
      raise ArgumentError,
            "target must be a string, but got #{target.class}"
    end
  end

  def attempts
    return @redis_attempts.to_i if defined?(@redis_attempts)

    fetch_state!

    @redis_attempts.to_i
  end

  def throttled?
    !expired? && maxed?
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
    return @redis_attempted_at if defined?(@redis_attempted_at)

    fetch_state!

    @redis_attempted_at
  end

  def expires_at
    return Time.zone.now if attempted_at.blank?
    attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
  end

  def remaining_count
    return 0 if throttled?

    Throttle.max_attempts(throttle_type) - attempts
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def maxed?
    attempts && attempts >= Throttle.max_attempts(throttle_type)
  end

  def increment!
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.incr(key)
        multi.expire(
          key,
          Throttle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i,
        )
      end
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = Time.zone.now

    attempts
  end

  # Retrieve the current state of the throttle from Redis
  # We use TTL to calculate when the action was last attempted.
  # This approach is introduces some skew since time passes
  # between "now" and when we fetch the TTL, but it should be low
  # relative to the overall length of the throttle window.
  #
  # When we upgrade to Redis 7, we can use the EXPIRETIME command instead.
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
        Time.zone.now -
        Throttle.attempt_window_in_minutes(throttle_type).minutes + ttl.seconds
    end

    self
  end

  def reset!
    REDIS_THROTTLE_POOL.with do |client|
      client.del(key)
    end

    @redis_attempts = 0
    @redis_attempted_at = nil
  end

  def increment_to_throttled!
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value = Throttle.max_attempts(throttle_type)
      client.setex(
        key,
        Throttle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i,
        value,
      )
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = Time.zone.now

    attempts
  end

  def key
    if @user
      "throttle:#{@user.id}:#{throttle_type}"
    else
      "throttle:#{@target}:#{throttle_type}"
    end
  end

  def self.attempt_window_in_minutes(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :attempt_window)
  end

  def self.max_attempts(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :max_attempts)
  end
end
