class Throttle < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true, unless: :target?
  validates :target, presence: true, unless: :user_id?

  enum throttle_type: {
    idv_doc_auth: 1,
    reg_unconfirmed_email: 2,
    reg_confirmed_email: 3,
    reset_password_email: 4,
    idv_resolution: 5,
    idv_send_link: 6,
    verify_personal_key: 7,
    verify_gpo_key: 8,
    proof_ssn: 9,
    proof_address: 10,
    phone_confirmation: 11,
  }

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

  # Either target or user must be supplied
  # @param [Symbol] throttle_type
  # @param [String] target
  # @param [User] user
  # @return [Throttle]
  def self.for(throttle_type:, user: nil, target: nil)
    throttle =
      if user
        find_or_create_by(user: user, throttle_type: throttle_type)
      elsif target
        if !target.is_a?(String)
          raise ArgumentError, "target must be a string, but got #{target.class}"
        end
        find_or_create_by(target: target, throttle_type: throttle_type)
      else
        raise 'Throttle must have a user or a target, but neither were provided'
      end

    throttle.reset_if_expired_and_maxed
    throttle
  end

  def self.attempt_window_in_minutes(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :attempt_window)
  end

  def self.max_attempts(throttle_type)
    THROTTLE_CONFIG.dig(throttle_type, :max_attempts)
  end

  # @return [Integer]
  def increment
    return attempts if maxed?
    update(attempts: self.read_attribute(:attempts) + 1, attempted_at: Time.zone.now)
    increment_redis
    attempts
  end

  def attempts
    if IdentityConfig.store.redis_throttle_enabled
      @redis_attempts.to_i
    else
      self.read_attribute(:attempts)
    end
  end

  def throttled?
    if IdentityConfig.store.redis_throttle_enabled
      attempts >= Throttle.max_attempts(throttle_type)
    else
      !expired? && maxed?
    end
  end

  def throttled_else_increment?
    if throttled?
      true
    else
      update(attempts: self.read_attribute(:attempts) + 1, attempted_at: Time.zone.now)
      increment_redis
      false
    end
  end

  def reset
    update(attempts: 0)
    reset_redis
    self
  end

  def remaining_count
    return 0 if throttled?

    Throttle.max_attempts(throttle_type) - attempts
  end

  def expires_at
    if IdentityConfig.store.redis_throttle_enabled
      return Time.zone.now if @redis_attempted_at.blank?
      @redis_attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
    else
      db_attempted_at = self.read_attribute(:attempted_at)
      return Time.zone.now if db_attempted_at.blank?
      db_attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
    end
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def maxed?
    if IdentityConfig.store.redis_throttle_enabled
      @redis_attempts && @redis_attempts >= Throttle.max_attempts(throttle_type)
    else
      attempts >= Throttle.max_attempts(throttle_type)
    end
  end

  def key
    if target
      "target:#{target}:#{throttle_type}"
    elsif user_id
      "user:#{user_id}:#{throttle_type}"
    end
  end

  def redis_attempts
    return @redis_attempts if defined?(@redis_attempts)

    fetch_redis_state!

    @redis_attempts
  end

  def redis_attempted_at
    return @redis_attempted_at if defined?(@redis_attempted_at)

    fetch_redis_state!

    @redis_attempted_at
  end

  def increment_redis
    value = nil
    REDIS_THROTTLE_POOL.with do |client|
      value, _success = client.multi do |multi|
        multi.incr(key)
        multi.expire(key, Throttle.attempt_window_in_minutes(throttle_type).minutes.seconds.to_i)
      end
    end

    @redis_attempts = value.to_i
    @redis_attempted_at = Time.zone.now
  end

  def fetch_redis_state!
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
      @redis_attempted_at = Time.zone.now +
                            Throttle.attempt_window_in_minutes(throttle_type).minutes - ttl.seconds
    end

    nil
  end

  def reset_redis
    REDIS_THROTTLE_POOL.with do |client|
      client.del(key)
    end

    @redis_attempts = 0
    @redis_attempted_at = nil
  end

  # @api private
  def reset_if_expired_and_maxed
    return unless expired? && maxed?
    update(attempts: 0, throttled_count: throttled_count.to_i + 1)
  end
end
