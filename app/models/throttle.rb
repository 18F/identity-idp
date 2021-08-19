class Throttle < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true, unless: :target?
  validates :target, presence: true, unless: :user_id?

  enum throttle_type: {
    idv_acuant: 1,
    reg_unconfirmed_email: 2,
    reg_confirmed_email: 3,
    reset_password_email: 4,
    idv_resolution: 5,
    idv_send_link: 6,
    verify_personal_key: 7,
    verify_gpo_key: 8,
    proof_ssn: 9,
  }

  THROTTLE_CONFIG = {
    idv_acuant: {
      max_attempts: IdentityConfig.store.acuant_max_attempts,
      attempt_window: IdentityConfig.store.acuant_attempt_window_in_minutes,
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
  }.freeze

  # Either target or user must be supplied
  # @param [Symbol] throttle_type
  # @param [String] target
  # @param [User] user
  # @return [Throttle]
  def self.for(throttle_type:, user: nil, target: nil)
    throttle = if user
      find_or_create_by(user: user, throttle_type: throttle_type)
    elsif target
      find_or_create_by(target: target, throttle_type: throttle_type)
    else
      raise 'Throttle must have a user or a target, but neither were provided'
    end

    throttle.reset_if_expired_and_maxed
    throttle
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
    max_attempts, _attempt_window_in_minutes = Throttle.config_values(throttle_type)
    max_attempts - attempts
  end

  def expired?
    return true if attempted_at.blank?
    _max_attempts, attempt_window_in_minutes = Throttle.config_values(throttle_type)
    attempted_at + attempt_window_in_minutes.to_i.minutes < Time.zone.now
  end

  def maxed?
    max_attempts, _attempt_window_in_minutes = Throttle.config_values(throttle_type)
    attempts >= max_attempts
  end

  def self.config_values(throttle_type)
    config = THROTTLE_CONFIG.with_indifferent_access[throttle_type]
    [config[:max_attempts], config[:attempt_window]]
  end

  # @api private
  def reset_if_expired_and_maxed
    return unless expired? && maxed?
    update(attempts: 0, throttled_count: throttled_count.to_i + 1)
  end
end
