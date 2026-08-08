# frozen_string_literal: true

class SignInRecaptchaForm
  include ActiveModel::Model

  RECAPTCHA_ACTION = 'sign_in'

  attr_reader :form_class, :form_args, :recaptcha_token, :ab_test_bucket,
              :assessment_id

  attr_writer :existing_device

  validate :validate_recaptcha_result

  def initialize(
    existing_device:,
    ab_test_bucket:,
    form_class:,
    **form_args
  )
    @existing_device = existing_device
    @ab_test_bucket = ab_test_bucket
    @form_class = form_class
    @form_args = form_args
  end

  def submit(recaptcha_token:)
    @recaptcha_token = recaptcha_token

    success = valid?
    FormResponse.new(success:, errors:)
  end

  def exempt?
    exempt_reason.present?
  end

  # Returns the reason a user is exempt from a reCAPTCHA assessment, or nil if
  # they are not exempt (i.e. an assessment is performed).
  # @return [Symbol, nil]
  def exempt_reason
    if IdentityConfig.store.sign_in_recaptcha_score_threshold.zero?
      :recaptcha_disabled
    elsif ab_test_bucket != :sign_in_recaptcha
      :not_in_ab_test
    elsif @existing_device
      :existing_device
    end
  end

  private

  def validate_recaptcha_result
    recaptcha_response, @assessment_id = recaptcha_form.submit(recaptcha_token)
    errors.merge!(recaptcha_form) if !recaptcha_response.success?
  end

  def recaptcha_form
    @recaptcha_form ||= form_class.new(
      score_threshold: exempt? ? 0.0 : IdentityConfig.store.sign_in_recaptcha_score_threshold,
      recaptcha_action: RECAPTCHA_ACTION,
      **form_args,
    )
  end
end
