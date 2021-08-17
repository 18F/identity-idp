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
  }.freeze

  # @param [User,Integer,String] target User, its ID, or a string identifier
  # @param [Symbol] throttle_type
  # @return [Throttle]
  def self.for(target:, throttle_type:)
    throttle = case target
    when User
      find_or_create_by(user: target, throttle_type: throttle_type)
    when Integer
      find_or_create_by(user_id: target, throttle_type: throttle_type)
    when String
      find_or_create_by(target: target, throttle_type: throttle_type)
    else
      raise "Unknown throttle target class=#{target.class}"
    end

    throttle.tap do |t|
      t.reset_if_expired_and_maxed
    end
  end

  # @return [Throttle]
  def increment
    return self if maxed?
    update(attempts: attempts + 1, attempted_at: Time.zone.now)
    self
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
