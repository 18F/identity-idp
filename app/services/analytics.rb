class Analytics
  def initialize(user, request)
    @user = user
    @request = request
  end

  def track_event(event, attributes = { user_id: uuid })
    attributes[:user_id] = uuid unless attributes.key?(:user_id)

    Rails.logger.info("#{event}: #{attributes}")

    ahoy.track(event, attributes.merge!(request_attributes))
  end

  private

  attr_reader :user, :request

  def request_attributes
    {
      user_ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  def ahoy
    @ahoy ||= Rails.env.test? ? FakeAhoyTracker.new : Ahoy::Tracker.new(request: request)
  end

  def uuid
    user.uuid
  end

  ACCOUNT_CREATED = 'Account Created'.freeze
  AUTHENTICATION_ATTEMPT = 'Authentication Attempt'.freeze
  AUTHENTICATION_ATTEMPT_NONEXISTENT = 'Authentication Attempt with nonexistent user'.freeze
  AUTHENTICATION_SUCCESFUL = 'Authentication Successful'.freeze
  EMAIL_CHANGE_REQUESTED = 'User asked to change their email'.freeze
  EMAIL_CHANGED_AND_CONFIRMED = 'Email changed and confirmed'.freeze
  EMAIL_CHANGED_TO_EXISTING = 'User attempted to change their email to an existing email'.freeze
  EMAIL_CONFIRMATION_INVALID_TOKEN = 'Invalid Email Confirmation Token'.freeze
  EMAIL_CONFIRMATION_TOKEN_EXPIRED = 'Email Confirmation: token expired'.freeze
  EMAIL_CONFIRMATION_USER_ALREADY_CONFIRMED = 'Email Confirmation: User Already Confirmed'.freeze
  EMAIL_CONFIRMATION_VALID_TOKEN = 'Email Confirmation: valid token'.freeze
  GET_REQUEST = 'GET Request'.freeze
  IDV_FAILED = 'IdV Failed'.freeze
  IDV_SUCCESSFUL = 'IdV Successful'.freeze
  INVALID_AUTHENTICITY_TOKEN = 'InvalidAuthenticityToken'.freeze
  INVALID_SERVICE_PROVIDER = :invalid_service_provider
  MAX_2FA_ATTEMPTS = 'User reached max 2FA attempts'.freeze
  OTP_RESULT = 'OTP'.freeze
  OTP_DELIVERY_SELECTION = :otp_delivery_selection
  PAGE_NOT_FOUND = :page_not_found
  PASSWORD_CHANGE = :password_change
  PASSWORD_CREATED_USER_CONFIRMED = 'Password Created and User Confirmed'.freeze
  PASSWORD_RESET = 'Password reset'.freeze
  PASSWORD_RESET_INVALID_PASSWORD = 'Reset password: invalid password'.freeze
  PASSWORD_RESET_INVALID_TOKEN = 'Reset password: invalid token'.freeze
  PASSWORD_RESET_REQUEST = 'Password Reset Request'.freeze
  PASSWORD_RESET_TOKEN_EXPIRED = 'Reset password: token expired'.freeze
  PHONE_CHANGE_REQUESTED = 'User asked to update their phone number'.freeze
  PHONE_CHANGED = 'User changed their phone number'.freeze
  RECOVERY_CODE_AUTHENTICATION = :recovery_code_authentication
  SAML_AUTH = 'SAML Auth'.freeze
  SESSION_TIMED_OUT = 'Session Timed Out'.freeze
  SETUP_2FA_INVALID_PHONE = '2FA setup: invalid phone number'.freeze
  SETUP_2FA_VALID_PHONE = '2FA setup: valid phone number'.freeze
  TOTP_AUTHENTICATION = :totp_authentication
  TOTP_SETUP_INVALID_CODE = 'TOTP Setup: invalid code'.freeze
  TOTP_SETUP_VALID_CODE = 'TOTP Setup: valid code'.freeze
  USER_DISABLED_TOTP = 'User Disabled TOTP'.freeze
  USER_REGISTRATION_EXISTING_EMAIL = 'Registration Attempt with existing email'.freeze
  USER_REGISTRATION_INVALID_EMAIL = 'User Registration: invalid email'.freeze
end
