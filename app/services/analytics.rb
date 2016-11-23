class Analytics
  def initialize(user, request)
    @user = user
    @request = request
  end

  def track_event(event, attributes = {})
    analytics_hash = {
      event: event,
      properties: attributes.except(:user_id),
      user_id: attributes[:user_id] || uuid
    }

    ANALYTICS_LOGGER.info(analytics_hash.merge!(request_attributes))
  end

  private

  attr_reader :user, :request

  def request_attributes
    {
      user_ip: request.remote_ip,
      user_agent: request.user_agent,
      host: request.host
    }
  end

  def uuid
    user.uuid
  end

  # rubocop:disable Metrics/LineLength
  AUTHENTICATION_MAX_2FA_ATTEMPTS = 'Authentication: user reached max 2FA attempts'.freeze
  EMAIL_AND_PASSWORD_AUTH = 'Email and Password Authentication'.freeze
  EMAIL_CHANGE_REQUESTED = 'Email Change: requested'.freeze
  EMAIL_CHANGED_TO_EXISTING = 'Email Change: user attempted to change their email to an existing email'.freeze
  EMAIL_CONFIRMATION = 'Email Confirmation'.freeze
  IDV_BASIC_INFO_VISIT = 'IdV: basic info visited'.freeze
  IDV_FAILED = 'IdV: failed'.freeze
  IDV_FINANCE_VISIT = 'IdV: finance visited'.freeze
  IDV_INTRO_VISIT = 'IdV: intro visited'.freeze
  IDV_PHONE_RECORD_VISIT = 'IdV: phone of record visited'.freeze
  IDV_REVIEW_VISIT = 'IdV: review info visited'.freeze
  IDV_SUCCESSFUL = 'IdV: successful'.freeze
  INVALID_AUTHENTICITY_TOKEN = 'Invalid Authenticity Token'.freeze
  INVALID_SERVICE_PROVIDER = 'Invalid Service Provider'.freeze
  OTP_DELIVERY_SELECTION = 'OTP: Delivery Selection'.freeze
  MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'.freeze
  MULTI_FACTOR_AUTH_ENTER_OTP_VISIT = 'Multi-Factor Authentication: enter OTP visited'.freeze
  PAGE_NOT_FOUND = 'Page Not Found'.freeze
  PASSWORD_CHANGED = 'Password Changed'.freeze
  PASSWORD_CREATION = 'Password Creation'.freeze
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
  SIGN_IN_PAGE_VISIT = 'Sign in page visited'.freeze
  TOTP_SETUP_INVALID_CODE = 'TOTP Setup: invalid code'.freeze
  TOTP_SETUP_VALID_CODE = 'TOTP Setup: valid code'.freeze
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'.freeze
  USER_REGISTRATION_EMAIL = 'User Registration: Email Submitted'.freeze
  USER_REGISTRATION_ENTER_EMAIL_VISIT = 'User Registration: enter email visited'.freeze
  USER_REGISTRATION_INTRO_VISIT = 'User Registration: intro visited'.freeze
  USER_REGISTRATION_PHONE_SETUP_VISIT = 'User Registration: phone setup visited'.freeze
  USER_REGISTRATION_RECOVERY_CODE_VISIT = 'User Registration: recovery code visited'.freeze
  # rubocop:enable Metrics/LineLength
end
