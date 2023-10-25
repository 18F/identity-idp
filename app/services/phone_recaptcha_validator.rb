# frozen_string_literal: true

class PhoneRecaptchaValidator
  RECAPTCHA_ACTION = 'phone_setup'

  attr_reader :parsed_phone, :validator_class, :validator_args

  delegate :valid?, :exempt?, to: :validator

  def initialize(parsed_phone:, validator_class: RecaptchaValidator, **validator_args)
    @parsed_phone = parsed_phone
    @validator_class = validator_class
    @validator_args = validator_args
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
    @validator ||= validator_class.new(
      score_threshold:,
      recaptcha_action: RECAPTCHA_ACTION,
      extra_analytics_properties: {
        phone_country_code: parsed_phone.country,
      },
      **validator_args,
    )
  end

  def score_threshold_country_override
    parsed_phone.valid_countries.
      map { |country| self.class.country_score_overrides[country.to_sym] }.
      compact.
      min
  end
end
