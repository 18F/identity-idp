# frozen_string_literal: true

class SignInRecaptchaForm
  include ActiveModel::Model

  RECAPTCHA_ACTION = 'sign_in'

  attr_reader :form_class, :form_args, :email, :recaptcha_token, :device_cookie, :ab_test_bucket,
              :assessment_id

  validate :validate_recaptcha_result

  def initialize(
    email:,
    device_cookie:,
    ab_test_bucket:,
    form_class: RecaptchaForm,
    **form_args
  )
    @email = email
    @device_cookie = device_cookie
    @ab_test_bucket = ab_test_bucket
    @form_class = form_class
    @form_args = form_args
  end

  def submit(recaptcha_token:)
    @recaptcha_token = recaptcha_token

    success = valid?
    FormResponse.new(success:, errors:, serialize_error_details_only: true)
  end

  def exempt?
    IdentityConfig.store.sign_in_recaptcha_score_threshold.zero? ||
      ab_test_bucket != :sign_in_recaptcha ||
      device.present?
  end

  private

  def validate_recaptcha_result
    recaptcha_response, @assessment_id = recaptcha_form.submit(recaptcha_token)
    errors.merge!(recaptcha_form) if !recaptcha_response.success?
  end

  def device
    User.find_with_confirmed_email(email)&.devices&.find_by(cookie_uuid: device_cookie)
  end

  def score_threshold
    if exempt?
      0.0
    else
      IdentityConfig.store.sign_in_recaptcha_score_threshold
    end
  end

  def recaptcha_form
    @recaptcha_form ||= form_class.new(
      score_threshold:,
      recaptcha_action: RECAPTCHA_ACTION,
      **form_args,
    )
  end
end
