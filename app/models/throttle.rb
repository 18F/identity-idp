class Throttle < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true

  enum throttle_type: {
    idv_acuant: 1,
    reg_unconfirmed_email: 2,
    reg_confirmed_email: 3,
    reset_password_email: 4,
  }

  THROTTLE_CONFIG = {
    idv_acuant: {
      max_attempts: (Figaro.env.acuant_max_attempts || 3).to_i,
      attempt_window: (Figaro.env.acuant_attempt_window_in_minutes || 1440).to_i,
    },
    reg_unconfirmed_email: {
      max_attempts: (Figaro.env.reg_unconfirmed_email_max_attempts || 20).to_i,
      attempt_window: (Figaro.env.reg_unconfirmed_email_window_in_minutes || 60).to_i,
    },
    reg_confirmed_email: {
      max_attempts: (Figaro.env.reg_confirmed_email_max_attempts || 20).to_i,
      attempt_window: (Figaro.env.reg_confirmed_email_window_in_minutes || 60).to_i,
    },
    reset_password_email: {
      max_attempts: (Figaro.env.reset_password_email_max_attempts || 20).to_i,
      attempt_window: (Figaro.env.reset_password_email_window_in_minutes || 60).to_i,
    },
  }.freeze

  def throttled?
    !expired? && maxed?
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
