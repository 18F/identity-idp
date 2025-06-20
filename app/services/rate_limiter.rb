# frozen_string_literal: true

# This class is similar to RedisRateLimiter, but differs in that
# the rate limit period begins once the maximum number of allowed
# attempts has been reached.
class RateLimiter
  attr_reader :rate_limit_type

  EXPONENTIAL_INCREMENT_SCRIPT = <<~LUA
    local count = redis.call('incr', KEYS[1])
    local now = tonumber(ARGV[1])
    local minutes = tonumber(ARGV[2])
    local exponential_factor = tonumber(ARGV[3])
    local attempt_window_max = tonumber(ARGV[4])
    minutes = math.floor(minutes * (exponential_factor ^ (count - 1)))
    if attempt_window_max then
      minutes = math.min(minutes, attempt_window_max)
    end
    redis.call('expireat', KEYS[1], now + (minutes * 60))
    return count
  LUA

  EXPONENTIAL_INCREMENT_SCRIPT_SHA1 = Digest::SHA1.hexdigest(EXPONENTIAL_INCREMENT_SCRIPT).freeze

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
    return @redis_attempts.to_i if defined?(@redis_attempts)

    fetch_state!

    @redis_attempts.to_i
  end

  def limited?
    !expired? && maxed?
  end

  def attempted_at
    return @redis_attempted_at if defined?(@redis_attempted_at)

    fetch_state!

    @redis_attempted_at
  end

  def expires_at
    return nil if attempted_at.blank?
    attempted_at + expiration_minutes.minutes
  end

  def remaining_count
    return 0 if limited?

    RateLimiter.max_attempts(rate_limit_type) - attempts
  end

  def expired?
    return nil if expires_at.nil?
    expires_at <= Time.zone.now
  end

  def maxed?
    attempts && attempts >= RateLimiter.max_attempts(rate_limit_type)
  end

  def expiration_minutes
    minutes = RateLimiter.attempt_window_in_minutes(rate_limit_type)
    exponential_factor = RateLimiter.attempt_window_exponential_factor(rate_limit_type)
    attempt_window_max = RateLimiter.attempt_window_max_in_minutes(rate_limit_type)
    minutes *= exponential_factor ** (attempts - 1) if exponential_factor && attempts.positive?
    if attempt_window_max && minutes > attempt_window_max
      attempt_window_max
    else
      minutes
    end
  end

  def increment!
    return if limited?
    value = nil

    minutes = RateLimiter.attempt_window_in_minutes(rate_limit_type)
    exponential_factor = RateLimiter.attempt_window_exponential_factor(rate_limit_type)
    now = Time.zone.now
    REDIS_THROTTLE_POOL.with do |client|
      if exponential_factor.present?
        attempt_window_max = RateLimiter.attempt_window_max_in_minutes(rate_limit_type)
        script_args = [now.to_i, minutes, exponential_factor, attempt_window_max].map(&:to_s)
        begin
          value = client.evalsha(EXPONENTIAL_INCREMENT_SCRIPT_SHA1, [key], script_args)
        rescue Redis::CommandError => error
          raise error unless error.message.start_with?('NOSCRIPT')
          value = client.eval(EXPONENTIAL_INCREMENT_SCRIPT, [key], script_args)
        end
      else
        value, _success = client.multi do |multi|
          multi.incr(key)
          multi.expireat(key, now + minutes.minutes.in_seconds)
        end
      end
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = now

    attempts
  end

  # Retrieve the current state of the rate limit from Redis
  # We use EXPIRETIME to calculate when the action was last attempted.
  def fetch_state!
    value = nil
    expiretime = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, expiretime = client.multi do |multi|
        multi.get(key)
        multi.expiretime(key)
      end
    end

    @redis_attempts = value.to_i

    if expiretime < 0
      @redis_attempted_at = nil
    else
      @redis_attempted_at =
        ActiveSupport::TimeZone['UTC'].at(expiretime).in_time_zone(Time.zone) -
        expiration_minutes.minutes
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

  def increment_to_limited!
    value = RateLimiter.max_attempts(rate_limit_type)
    now = Time.zone.now

    REDIS_THROTTLE_POOL.with do |client|
      client.set(
        key,
        value,
        exat: now + expiration_minutes.minutes.in_seconds,
      )
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = now

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

  def self.attempt_window_exponential_factor(rate_limit_type)
    rate_limit_config.dig(rate_limit_type, :attempt_window_exponential_factor)
  end

  def self.attempt_window_max_in_minutes(rate_limit_type)
    rate_limit_config.dig(rate_limit_type, :attempt_window_max)
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
      account_reset_request: {
        max_attempts: IdentityConfig.store.account_reset_request_max_attempts,
        attempt_window: IdentityConfig.store.account_reset_request_attempt_window_in_minutes,
      },
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
        attempt_window: IdentityConfig.store
          .short_term_phone_otp_max_attempt_window_in_seconds.seconds.in_minutes.to_f,
      },
      sign_in_user_id_per_ip: {
        max_attempts: IdentityConfig.store.sign_in_user_id_per_ip_max_attempts,
        attempt_window: IdentityConfig.store.sign_in_user_id_per_ip_attempt_window_in_minutes,
        attempt_window_exponential_factor:
          IdentityConfig.store.sign_in_user_id_per_ip_attempt_window_exponential_factor,
        attempt_window_max: IdentityConfig.store.sign_in_user_id_per_ip_attempt_window_max_minutes,
      },
      backup_code_user_id_per_ip: {
        max_attempts: IdentityConfig.store.backup_code_user_id_per_ip_max_attempts,
        attempt_window: IdentityConfig.store.backup_code_user_id_per_ip_attempt_window_in_minutes,
        attempt_window_exponential_factor:
          IdentityConfig.store.backup_code_user_id_per_ip_attempt_window_exponential_factor,
        attempt_window_max:
          IdentityConfig.store.backup_code_user_id_per_ip_attempt_window_max_minutes,
      },
    }.with_indifferent_access
  end

  CACHED_RATE_LIMIT_CONFIG = self.load_rate_limit_config.with_indifferent_access.freeze
end
