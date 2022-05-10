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
    redis_throttle.increment!
    attempts
  end

  def attempts
    if IdentityConfig.store.redis_throttle_enabled
      redis_throttle.attempts
    else
      self.read_attribute(:attempts)
    end
  end

  def throttled?
    if IdentityConfig.store.redis_throttle_enabled
      redis_throttle.attempts >= Throttle.max_attempts(throttle_type)
    else
      !expired? && maxed?
    end
  end

  def throttled_else_increment?
    if throttled?
      true
    else
      update(attempts: attempts + 1, attempted_at: Time.zone.now)
      redis_throttle.increment!
      false
    end
  end

  def reset
    update(attempts: 0)
    redis_throttle.reset!
    self
  end

  def remaining_count
    return 0 if throttled?

    if IdentityConfig.store.redis_throttle_enabled
      Throttle.max_attempts(throttle_type) - redis_throttle.attempts
    else
      Throttle.max_attempts(throttle_type) - attempts
    end
  end

  def expires_at
    if IdentityConfig.store.redis_throttle_enabled
      return Time.zone.now if redis_throttle.attempted_at.blank?
      redis_throttle.attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
    else
      return Time.zone.now if attempted_at.blank?
      attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
    end
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def maxed?
    if IdentityConfig.store.redis_throttle_enabled
      redis_throttle.attempts && redis_throttle.attempts >= Throttle.max_attempts(throttle_type)
    else
      attempts >= Throttle.max_attempts(throttle_type)
    end
  end

  def redis_attempts
    redis_throttle.attempts
  end

  # @api private
  def reset_if_expired_and_maxed
    return unless expired? && maxed?
    update(attempts: 0, throttled_count: throttled_count.to_i + 1)
  end

  def redis_throttle
    return @redis_throttle if defined?(@redis_throttle)
    redis_throttle_target = target || self.user_id
    @redis_throttle = RedisThrottle.new(throttle_type: throttle_type, target: redis_throttle_target)

    @redis_throttle
  end
end
