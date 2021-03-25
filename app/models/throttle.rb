class Throttle < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true

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
      max_attempts: AppConfig.env.acuant_max_attempts.to_i,
      attempt_window: AppConfig.env.acuant_attempt_window_in_minutes.to_i,
    },
    reg_unconfirmed_email: {
      max_attempts: AppConfig.env.reg_unconfirmed_email_max_attempts.to_i,
      attempt_window: AppConfig.env.reg_unconfirmed_email_window_in_minutes.to_i,
    },
    reg_confirmed_email: {
      max_attempts: AppConfig.env.reg_confirmed_email_max_attempts.to_i,
      attempt_window: AppConfig.env.reg_confirmed_email_window_in_minutes.to_i,
    },
    reset_password_email: {
      max_attempts: AppConfig.env.reset_password_email_max_attempts.to_i,
      attempt_window: AppConfig.env.reset_password_email_window_in_minutes.to_i,
    },
    idv_resolution: {
      max_attempts: AppConfig.env.idv_max_attempts.to_i,
      attempt_window: AppConfig.env.idv_attempt_window_in_hours.to_i * 60,
    },
    idv_send_link: {
      max_attempts: AppConfig.env.idv_send_link_max_attempts.to_i,
      attempt_window: AppConfig.env.idv_send_link_attempt_window_in_minutes.to_i,
    },
    verify_personal_key: {
      max_attempts: AppConfig.env.verify_personal_key_max_attempts.to_i,
      attempt_window: AppConfig.env.verify_personal_key_attempt_window_in_minutes.to_i,
    },
    verify_gpo_key: {
      max_attempts: AppConfig.env.verify_gpo_key_max_attempts.to_i,
      attempt_window: AppConfig.env.verify_gpo_key_attempt_window_in_minutes.to_i,
    },
  }.freeze

  def throttled?
    !expired? && maxed?
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
end
