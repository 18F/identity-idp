class Analytics
  def initialize(user, request)
    @user = user
    @request = request
  end

  def track_event(event, attributes = { user_id: uuid })
    attributes[:user_id] = uuid unless attributes.key?(:user_id)

    consolidated_attributes = attributes.merge!(request_attributes)

    Rails.logger.info(consolidated_attributes.merge(event: event))
  end

  private

  attr_reader :user, :request

  def request_attributes
    {
      user_ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  def uuid
    user.uuid
  end

  # rubocop:disable Metrics/LineLength
  AUTHENTICATION_MAX_2FA_ATTEMPTS = 'Authentication: user reached max 2FA attempts'.freeze
  EMAIL_AND_PASSWORD_AUTH = 'Email and Password Authentication'.freeze
  EMAIL_CHANGE_REQUESTED = 'Email Change: requested'.freeze
  EMAIL_CHANGED_AND_CONFIRMED = 'Email Change: changed and confirmed'.freeze
  EMAIL_CHANGED_TO_EXISTING = 'Email Change: user attempted to change their email to an existing email'.freeze
  EMAIL_CONFIRMATION_INVALID_TOKEN = 'Email Confirmation: invalid email confirmation token'.freeze
  EMAIL_CONFIRMATION_TOKEN_EXPIRED = 'Email Confirmation: token expired'.freeze
  EMAIL_CONFIRMATION_USER_ALREADY_CONFIRMED = 'Email Confirmation: user already confirmed'.freeze
  EMAIL_CONFIRMATION_VALID_TOKEN = 'Email Confirmation: valid token'.freeze
  IDV_FAILED = 'IdV: Failed'.freeze
  IDV_SUCCESSFUL = 'IdV: Successful'.freeze
  INVALID_AUTHENTICITY_TOKEN = 'Invalid Authenticity Token'.freeze
  INVALID_SERVICE_PROVIDER = 'Invalid Service Provider'.freeze
  OTP_DELIVERY_SELECTION = 'OTP: Delivery Selection'.freeze
  MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'.freeze
  PAGE_NOT_FOUND = 'Page Not Found'.freeze
  PASSWORD_CHANGED = 'Password Changed'.freeze
  PASSWORD_CREATE_INVALID = 'Password Create: invalid password'.freeze
  PASSWORD_CREATE_USER_CONFIRMED = 'Password Create: created and user confirmed'.freeze
  PASSWORD_RESET_DEACTIVATED_ACCOUNT = 'Password Reset: deactivated verified profile via password reset'.freeze
  PASSWORD_RESET_EMAIL = 'Password Reset: Email Submitted'.freeze
  PASSWORD_RESET_PASSWORD = 'Password Reset: Password Submitted'.freeze
  PASSWORD_RESET_TOKEN = 'Password Reset: Token Submitted'.freeze
  PHONE_CHANGE_REQUESTED = 'Phone Number Change: requested'.freeze
  PHONE_CHANGE_SUCCESSFUL = 'Phone Number Change: successful'.freeze
  PROFILE_ENCRYPTION_INVALID = 'Profile Encryption: Invalid'.freeze
  SAML_AUTH = 'SAML Auth'.freeze
  SESSION_TIMED_OUT = 'Session Timed Out'.freeze
  SETUP_2FA_INVALID_PHONE = '2FA setup: invalid phone number'.freeze
  SETUP_2FA_VALID_PHONE = '2FA setup: valid phone number'.freeze
  TOTP_SETUP_INVALID_CODE = 'TOTP Setup: invalid code'.freeze
  TOTP_SETUP_VALID_CODE = 'TOTP Setup: valid code'.freeze
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'.freeze
  USER_REGISTRATION_ACCOUNT_CREATED = 'User Registration: Account Created'.freeze
  USER_REGISTRATION_EXISTING_EMAIL = 'User Registration: Attempt with existing email'.freeze
  USER_REGISTRATION_INVALID_EMAIL = 'User Registration: invalid email'.freeze
  # rubocop:enable Metrics/LineLength
end
