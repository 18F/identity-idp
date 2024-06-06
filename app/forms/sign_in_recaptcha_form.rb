# frozen_string_literal: true

class SignInRecaptchaForm
  include ActiveModel::Model

  RECAPTCHA_ACTION = 'sign_in'

  attr_reader :form_class, :form_args, :email, :recaptcha_token, :device_cookie

  validate :validate_device_cookie

  def initialize(form_class: RecaptchaForm, **form_args)
    @form_class = form_class
    @form_args = form_args
  end

  def submit(email:, recaptcha_token:, device_cookie:)
    @email = email
    @recaptcha_token = recaptcha_token
    @device_cookie = device_cookie

    success = valid?
    FormResponse.new(success:, errors:, serialize_error_details_only: true)
  end

  private

  def validate_device_cookie
    return if exempt?
    recaptcha_response, _assessment_id = recaptcha_form.submit(recaptcha_token)
    return if recaptcha_response.success?
    errors.merge!(recaptcha_form)
  end

  def exempt?
    device.present?
  end

  def device
    User.find_with_confirmed_email(email)&.devices&.find_by(cookie_uuid: device_cookie)
  end

  def recaptcha_form
    @recaptcha_form ||= form_class.new(
      score_threshold: IdentityConfig.store.sign_in_recaptcha_score_threshold,
      recaptcha_action: RECAPTCHA_ACTION,
      **form_args,
    )
  end
end
