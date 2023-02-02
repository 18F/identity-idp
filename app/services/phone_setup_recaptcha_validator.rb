class PhoneSetupRecaptchaValidator < RecaptchaValidator
  attr_reader :parsed_phone

  def initialize(parsed_phone:, **recaptcha_validator_options)
    super(**recaptcha_validator_options)

    @parsed_phone = parsed_phone
  end

  def self.exempt_countries
    country_score_overrides.select { |_key, value| !value.positive? }.keys
  end

  def self.country_score_overrides
    IdentityConfig.store.phone_setup_recaptcha_country_score_overrides
  end

  def score_threshold
    score_threshold_country_override || IdentityConfig.store.phone_setup_recaptcha_score_threshold
  end

  private

  def score_threshold_country_override
    parsed_phone.valid_countries.
      map { |country| self.class.country_score_overrides[country.to_sym] }.
      compact.
      min
  end
end
