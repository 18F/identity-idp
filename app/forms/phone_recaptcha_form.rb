# frozen_string_literal: true

class PhoneRecaptchaForm
  RECAPTCHA_ACTION = 'phone_setup'

  attr_reader :parsed_phone, :form_class, :form_args

  delegate :submit, :errors, to: :form

  def initialize(parsed_phone:, form_class: RecaptchaForm, **form_args)
    @parsed_phone = parsed_phone
    @form_class = form_class
    @form_args = form_args
  end

  def self.country_score_overrides
    IdentityConfig.store.phone_recaptcha_country_score_overrides
  end

  def score_threshold
    score_threshold_country_override || IdentityConfig.store.phone_recaptcha_score_threshold
  end

  private

  def form
    @form ||= form_class.new(
      score_threshold:,
      recaptcha_action: RECAPTCHA_ACTION,
      extra_analytics_properties: {
        phone_country_code: parsed_phone.country,
      },
      **form_args,
    )
  end

  def score_threshold_country_override
    parsed_phone.valid_countries
      .map { |country| self.class.country_score_overrides[country.to_sym] }
      .compact
      .min
  end
end
