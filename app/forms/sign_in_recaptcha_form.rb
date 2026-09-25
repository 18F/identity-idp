# frozen_string_literal: true

class SignInRecaptchaForm < RecaptchaForm
  RECAPTCHA_ACTION = 'sign_in'

  attr_writer :existing_device

  def initialize(existing_device:, form_class:, **form_args)
    @existing_device = existing_device
    super(form_class:, **form_args)
  end

  def exempt?
    IdentityConfig.store.sign_in_recaptcha_score_threshold.zero? ||
      @existing_device
  end

  private

  def score_threshold
    if exempt?
      0.0
    else
      IdentityConfig.store.sign_in_recaptcha_score_threshold
    end
  end
end
