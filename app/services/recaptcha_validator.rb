class RecaptchaValidator
  def initialize(key = nil, verified = true, response_present = true)
    @key = key
    @verified = verified
    @response_present = response_present
  end

  def valid?
    # When the reCAPTCHA feature is disabled, it should always be
    # considered valid
    @valid ||= enabled? ? verified : true
  end

  def enabled?
    @enabled ||= FeatureManagement.recaptcha_enabled?(key)
  end

  def extra_analytics_attributes
    {
      recaptcha_valid: verified,
      recaptcha_present: response_present,
      recaptcha_enabled: enabled?,
    }
  end

  private

  attr_reader :key, :verified, :response_present
end
