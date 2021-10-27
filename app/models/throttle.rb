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
  }.with_indifferent_access.freeze

  # Either target or user must be supplied
  # @param [Symbol] throttle_type
  # @param [String] target
  # @param [User] user
  # @return [Throttle]
  def self.for(throttle_type:, user: nil, target: nil)
    throttle = if user
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
    update(attempts: attempts + 1, attempted_at: Time.zone.now)
    attempts
  end

  def throttled?
    !expired? && maxed?
  end

  def throttled_else_increment?
    if throttled?
      true
    else
      update(attempts: attempts + 1, attempted_at: Time.zone.now)
      false
    end
  end

  def reset
    update(attempts: 0)
    self
  end

  def remaining_count
    return 0 if throttled?
    Throttle.max_attempts(throttle_type) - attempts
  end

  def expires_at
    return Time.zone.now if attempted_at.blank?
    attempted_at + Throttle.attempt_window_in_minutes(throttle_type).minutes
  end

  def expired?
    expires_at <= Time.zone.now
  end

  def maxed?
    attempts >= Throttle.max_attempts(throttle_type)
  end

  # @api private
  def reset_if_expired_and_maxed
    return unless expired? && maxed?
    update(attempts: 0, throttled_count: throttled_count.to_i + 1)
  end
end
