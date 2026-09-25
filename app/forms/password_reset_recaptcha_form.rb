# frozen_string_literal: true

class PasswordResetRecaptchaForm < RecaptchaForm
  RECAPTCHA_ACTION = 'password_reset'

  def exempt?
    return false if IdentityConfig.store.password_reset_recaptcha_enabled

    score_threshold.zero?
  end

  private

  def score_threshold
    IdentityConfig.store.password_reset_recaptcha_score_threshold
  end
end
