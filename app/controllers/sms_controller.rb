class SmsController < ApplicationController
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include SecureHeadersConcern

  # Twilio supports HTTP Basic Auth for request URL
  # https://www.twilio.com/docs/usage/security
  before_action :authenticate

  # Disable CSRF check
  skip_before_action :verify_authenticity_token, only: [:receive]

  def receive
    result = sms_responder.call

    result.success? ? process_success(result) : process_failure(result)
  end

  private

  def process_success(result)
    analytics.track_event(
      Analytics::TWILIO_SMS_INBOUND_MESSAGE_RECEIVED,
      result.to_h,
    )
    head :accepted
  end

  def process_failure(result)
    analytics.track_event(
      Analytics::TWILIO_SMS_INBOUND_MESSAGE_VALIDATION_FAILED,
      result.to_h,
    )

    if !sms_responder.signature_valid?
      head :forbidden
    else
      head :ok
    end
  end

  # `http_basic_authenticate_with name` had issues related to testing, so using
  # this method with a before action instead. (The former is a shortcut for the
  # following, which is called internally by Rails.)
  def authenticate
    env = Figaro.env

    head :unauthorized unless auth_configured?(env)

    authenticate_or_request_with_http_basic do |username, password|
      # This comparison uses & so that it doesn't short circuit and
      # uses `secure_compare` so that length information
      # isn't leaked.
      ActiveSupport::SecurityUtils.secure_compare(
        username, env.twilio_http_basic_auth_username
      ) & ActiveSupport::SecurityUtils.secure_compare(
        password, env.twilio_http_basic_auth_password
      )
    end
  end

  def auth_configured?(env)
    env.twilio_http_basic_auth_username.present? &&
      env.twilio_http_basic_auth_password.present?
  end

  def sms_responder
    @sms_responder ||= begin
      signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
      SmsResponder.new(request.url, params, signature)
    end
  end
end
