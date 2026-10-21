# frozen_string_literal: true

class AccountCreationRecaptchaForm < RecaptchaForm
  RECAPTCHA_ACTION = 'account_creation'

  def exempt?
    score_threshold.zero?
  end

  private

  def score_threshold
    IdentityConfig.store.account_creation_recaptcha_score_threshold
  end
end
