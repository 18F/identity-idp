module Recaptchable
  extend ActiveSupport::Concern

  # Call the validation service with the following external parameters:
  # - verify_recaptcha: https://github.com/ambethia/recaptcha#verify_recaptcha
  # - g-recaptcha-response: https://developers.google.com/recaptcha/docs/verify
  def validate_recaptcha
    RecaptchaValidator.new(
      controller_action,
      verify_recaptcha,
      params[:'g-recaptcha-response'].present?
    )
  end

  private

  def controller_action
    "#{controller_path}##{action_name}"
  end
end
