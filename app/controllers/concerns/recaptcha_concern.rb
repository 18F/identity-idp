module RecaptchaConcern
  private

  def validate_recaptcha
    enabled = FeatureManagement.recaptcha_enabled?(session, false)
    recaptcha_valid = verify_recaptcha
    allow = enabled ? recaptcha_valid : true
    result_h = {
      recaptcha_valid: recaptcha_valid,
      recaptcha_present: params[:'g-recaptcha-response'].present?,
      recaptcha_enabled: enabled,
    }
    [allow, result_h]
  end
end
