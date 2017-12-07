class Analytics
  def initialize(user:, request:, sp:)
    @user = user
    @request = request
    @sp = sp
  end

  def track_event(event, attributes = {})
    analytics_hash = {
      event_properties: attributes.except(:user_id),
      user_id: attributes[:user_id] || uuid,
    }
    ahoy.track(event, analytics_hash.merge!(request_attributes))
  end

  private

  attr_reader :user, :request, :sp

  def ahoy
    @ahoy ||= Rails.env.test? ? FakeAhoyTracker.new : Ahoy::Tracker.new(request: request)
  end

  def request_attributes
    {
      user_ip: request.remote_ip,
      host: request.host,
      pid: Process.pid,
      service_provider: sp,
    }.merge!(browser_attributes)
  end

  # rubocop:disable Metrics/AbcSize
  def browser_attributes
    {
      user_agent: request.user_agent,
      browser_name: browser.name,
      browser_version: browser.full_version,
      browser_platform_name: browser.os_name,
      browser_platform_version: browser.os_full_version,
      browser_device_name: browser.device_name,
      browser_device_type: browser.device_type,
      browser_bot: browser.bot?,
    }
  end
  # rubocop:enable Metrics/AbcSize

  def uuid
    user.uuid
  end

  def browser
    @browser ||= DeviceDetector.new(request.user_agent)
  end

  ACCOUNT_VISIT = 'Account Page Visited'.freeze
  EMAIL_AND_PASSWORD_AUTH = 'Email and Password Authentication'.freeze
  EMAIL_CHANGE_REQUEST = 'Email Change Request'.freeze
  EMAIL_CONFIRMATION = 'Email Confirmation'.freeze
  EMAIL_CONFIRMATION_RESEND = 'Email Confirmation requested due to invalid token'.freeze
  IDV_BASIC_INFO_VISIT = 'IdV: basic info visited'.freeze
  IDV_BASIC_INFO_SUBMITTED_FORM = 'IdV: basic info form submitted'.freeze
  IDV_BASIC_INFO_SUBMITTED_VENDOR = 'IdV: basic info vendor submitted'.freeze
  IDV_MAX_ATTEMPTS_EXCEEDED = 'IdV: max attempts exceeded'.freeze
  IDV_FINAL = 'IdV: final resolution'.freeze
  IDV_INTRO_VISIT = 'IdV: intro visited'.freeze
  IDV_PHONE_CONFIRMATION_FORM = 'IdV: phone confirmation form'.freeze
  IDV_PHONE_CONFIRMATION_VENDOR = 'IdV: phone confirmation vendor'.freeze
  IDV_PHONE_RECORD_VISIT = 'IdV: phone of record visited'.freeze
  IDV_REVIEW_COMPLETE = 'IdV: review complete'.freeze
  IDV_REVIEW_VISIT = 'IdV: review info visited'.freeze
  INVALID_AUTHENTICITY_TOKEN = 'Invalid Authenticity Token'.freeze
  LOGOUT_INITIATED = 'Logout Initiated'.freeze
  MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'.freeze
  MULTI_FACTOR_AUTH_ENTER_OTP_VISIT = 'Multi-Factor Authentication: enter OTP visited'.freeze
  MULTI_FACTOR_AUTH_MAX_ATTEMPTS = 'Multi-Factor Authentication: max attempts reached'.freeze
  MULTI_FACTOR_AUTH_PHONE_SETUP = 'Multi-Factor Authentication: phone setup'.freeze
  MULTI_FACTOR_AUTH_MAX_SENDS = 'Multi-Factor Authentication: max otp sends reached'.freeze
  OPENID_CONNECT_BEARER_TOKEN = 'OpenID Connect: bearer token authentication'.freeze
  OPENID_CONNECT_REQUEST_AUTHORIZATION = 'OpenID Connect: authorization request'.freeze
  OPENID_CONNECT_TOKEN = 'OpenID Connect: token'.freeze
  OTP_DELIVERY_SELECTION = 'OTP: Delivery Selection'.freeze
  PASSWORD_CHANGED = 'Password Changed'.freeze
  PASSWORD_CREATION = 'Password Creation'.freeze
  PASSWORD_MAX_ATTEMPTS = 'Password Max Attempts Reached'.freeze
  PASSWORD_RESET_EMAIL = 'Password Reset: Email Submitted'.freeze
  PASSWORD_RESET_PASSWORD = 'Password Reset: Password Submitted'.freeze
  PASSWORD_RESET_TOKEN = 'Password Reset: Token Submitted'.freeze
  PHONE_CHANGE_REQUESTED = 'Phone Number Change: requested'.freeze
  PROFILE_ENCRYPTION_INVALID = 'Profile Encryption: Invalid'.freeze
  PROFILE_PERSONAL_KEY_CREATE = 'Profile: Created new personal key'.freeze
  SAML_AUTH = 'SAML Auth'.freeze
  SESSION_TIMED_OUT = 'Session Timed Out'.freeze
  SIGN_IN_PAGE_VISIT = 'Sign in page visited'.freeze
  TOTP_SETUP = 'TOTP Setup'.freeze
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'.freeze
  TWILIO_PHONE_VALIDATION_FAILED = 'Twilio Phone Validation Failed'.freeze
  USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT = 'User registration: agency handoff visited'.freeze
  USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE = 'User registration: agency handoff complete'.freeze
  USER_REGISTRATION_EMAIL = 'User Registration: Email Submitted'.freeze
  USER_REGISTRATION_ENTER_EMAIL_VISIT = 'User Registration: enter email visited'.freeze
  USER_REGISTRATION_INTRO_VISIT = 'User Registration: intro visited'.freeze
  USER_REGISTRATION_PHONE_SETUP_VISIT = 'User Registration: phone setup visited'.freeze
  USER_REGISTRATION_PERSONAL_KEY_VISIT = 'User Registration: personal key visited'.freeze
end
