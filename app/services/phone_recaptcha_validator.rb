class PhoneRecaptchaValidator
  attr_reader :parsed_phone, :analytics

  delegate :valid?, :exempt?, to: :validator

  def initialize(parsed_phone:, analytics: nil)
    @parsed_phone = parsed_phone
    @analytics = analytics
  end

  def self.exempt_countries
    country_score_overrides.select { |_key, value| !value.positive? }.keys
  end

  def self.country_score_overrides
    IdentityConfig.store.phone_recaptcha_country_score_overrides
  end

  def score_threshold
    score_threshold_country_override || IdentityConfig.store.phone_recaptcha_score_threshold
  end

  private

  def validator
    @validator ||= RecaptchaValidator.new(score_threshold:, analytics:)
  end

  def score_threshold_country_override
    parsed_phone.valid_countries.
      map { |country| self.class.country_score_overrides[country.to_sym] }.
      compact.
      min
  end
end
