# frozen_string_literal: true

# This class is similar to RedisRateLimiter, but differs in that
# the rate limit period begins once the maximum number of allowed
# attempts has been reached.
class RateLimiter
  attr_reader :rate_limit_type

  def initialize(rate_limit_type:, user: nil, target: nil)
    @rate_limit_type = rate_limit_type
    @user = user
    @target = target

    unless RateLimiter.rate_limit_config.key?(rate_limit_type)
      raise ArgumentError,
            'rate_limit_type is not valid'
    end
    if @user.blank? && @target.blank?
      raise ArgumentError, 'RateLimiter must have a user or a target, but neither were provided'
    end

    if @user.present? && @target.present?
      raise ArgumentError, 'RateLimiter must have a user or a target, but both were provided'
    end

    if target && !target.is_a?(String)
      raise ArgumentError,
            "target must be a string, but got #{target.class}"
    end
  end

  def attempts
    fetch_state! if !defined?(@redis_attempts)
    @redis_attempts
  end

  def limited?
    !expired? && maxed?
  end

  def remaining_count
    return 0 if limited?

    RateLimiter.max_attempts(rate_limit_type) - attempts
  end

  def expired?
    !@redis_expires_at || @redis_expires_at <= Time.zone.now
  end

  def maxed?
    attempts >= RateLimiter.max_attempts(rate_limit_type)
  end

  def increment!
    return if limited?
    value = nil

    now = Time.zone.now
    expires_at = now + RateLimiter.attempt_window_in_minutes(rate_limit_type).minutes.in_seconds
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.incr(key)
        multi.expireat(key, expires_at)
      end
    end

    @redis_attempts = value.to_i
    @redis_expires_at = expires_at

    attempts
  end

  # Retrieve the current state of the rate limit from Redis
  # We use EXPIRETIME to calculate when the action was last attempted.
  def fetch_state!
    REDIS_THROTTLE_POOL.with do |client|
      value = client.get(key)
      @redis_attempts = value.to_i
    end
  end

  def reset!
    REDIS_THROTTLE_POOL.with do |client|
      client.del(key)
    end

    @redis_attempts = 0
    @redis_attempted_at = nil
  end

  def increment_to_limited!
    value = RateLimiter.max_attempts(rate_limit_type)
    now = Time.zone.now
    expires_at = now + RateLimiter.attempt_window_in_minutes(rate_limit_type).minutes.in_seconds

    REDIS_THROTTLE_POOL.with do |client|
      client.set(key, value, exat: expires_at)
    end

    @redis_attempts = value.to_i
    @redis_expires_at = expires_at

    attempts
  end

  # still uses throttle terminology because of persisted data in redis
  def key
    if @user
      "throttle:throttle:#{@user.id}:#{rate_limit_type}"
    else
      "throttle:throttle:#{@target}:#{rate_limit_type}"
    end
  end

  def self.attempt_window_in_minutes(rate_limit_type)
    rate_limit_config.dig(rate_limit_type, :attempt_window)
  end

  def self.max_attempts(rate_limit_type)
    rate_limit_config.dig(rate_limit_type, :max_attempts)
  end

  def self.rate_limit_config
    if Rails.env.production?
      CACHED_RATE_LIMIT_CONFIG
    else
      load_rate_limit_config
    end
  end

  def self.load_rate_limit_config
    {
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
      phone_otp: {
        max_attempts: IdentityConfig.store.otp_delivery_blocklist_maxretry + 1,
        attempt_window: IdentityConfig.store.otp_delivery_blocklist_findtime,
      },
      short_term_phone_otp: {
        max_attempts: IdentityConfig.store.short_term_phone_otp_max_attempts,
        attempt_window: IdentityConfig.store.
          short_term_phone_otp_max_attempt_window_in_seconds.seconds.in_minutes.to_f,
      },
    }.with_indifferent_access
  end

  CACHED_RATE_LIMIT_CONFIG = self.load_rate_limit_config.with_indifferent_access.freeze
end
