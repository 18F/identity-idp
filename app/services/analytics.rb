# rubocop:disable Metrics/ClassLength
class Analytics
  # :reek:ControlParameter
  def initialize(user:, request:, sp:, ahoy: nil)
    @user = user
    @request = request
    @sp = sp
    @ahoy = ahoy || Ahoy::Tracker.new(request: request)
  end

  def track_event(event, attributes = {})
    analytics_hash = {
      event_properties: attributes.except(:user_id),
      user_id: attributes[:user_id] || user.uuid,
    }
    ahoy.track(event, analytics_hash.merge!(request_attributes))
  end

  # :reek:FeatureEnvy
  def track_mfa_submit_event(attributes, ga_client_id)
    track_event(MULTI_FACTOR_AUTH, attributes)
    mfa_event_type = (attributes[:success] ? 'success' : 'fail')

    GoogleAnalyticsMeasurement.new(
      category: 'authentication',
      event_action: "multi+factor+#{mfa_event_type}",
      method: attributes[:multi_factor_auth_method],
      client_id: ga_client_id,
    ).send_event
  end

  attr_reader :user, :request, :sp, :ahoy

  def request_attributes
    {
      user_ip: request.remote_ip,
      hostname: request.host,
      pid: Process.pid,
      service_provider: sp,
    }.merge!(browser_attributes)
  end

  def browser
    @browser ||= DeviceDetector.new(request.user_agent)
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

  # rubocop:disable Metrics/LineLength
  ACCOUNT_RESET = 'Account Reset'.freeze
  ACCOUNT_DELETION = 'Account Deletion Requested'.freeze
  ACCOUNT_RESET_VISIT = 'Account deletion and reset visited'.freeze
  ACCOUNT_VISIT = 'Account Page Visited'.freeze
  ADD_EMAIL = 'Add Email: Email Submitted'.freeze
  ADD_EMAIL_CONFIRMATION = 'Add Email: Email Confirmation'.freeze
  ADD_EMAIL_CONFIRMATION_RESEND = 'Add Email: Email Confirmation requested due to invalid token'.freeze
  ADD_EMAIL_VISIT = 'Add Email: enter email visited'.freeze
  CAC_PROOFING = 'CAC Proofing'.freeze # visited or submitted is appended
  CAPTURE_DOC = 'Capture Doc'.freeze # visited or submitted is appended
  DOC_AUTH = 'Doc Auth'.freeze # visited or submitted is appended
  IN_PERSON_PROOFING = 'In Person Proofing'.freeze # visited or submitted is appended
  EMAIL_AND_PASSWORD_AUTH = 'Email and Password Authentication'.freeze
  EMAIL_DELETION_REQUEST = 'Email Deletion Requested'.freeze
  EVENT_DISAVOWAL = 'Event disavowal visited'.freeze
  EVENT_DISAVOWAL_PASSWORD_RESET = 'Event disavowal password reset'.freeze
  EVENT_DISAVOWAL_TOKEN_INVALID = 'Event disavowal token invalid'.freeze
  EVENTS_VISIT = 'Events Page Visited'.freeze
  EXPIRED_LETTERS = 'Expired Letters'.freeze
  FRONTEND_BROWSER_CAPABILITIES = 'Frontend: Browser capabilities'.freeze
  IAL2_RECOVERY = 'IAL2 Recovery'.freeze # visited or submitted is appended
  IAL2_RECOVERY_REQUEST = 'IAL2 Recovery Request'.freeze
  IAL2_RECOVERY_REQUEST_VISITED = 'IAL2 Recovery Request Visited'.freeze
  IDV_ADDRESS_VISIT = 'IdV: address visited'.freeze
  IDV_ADDRESS_SUBMITTED = 'IdV: address submitted'.freeze
  IDV_BASIC_INFO_VISIT = 'IdV: basic info visited'.freeze
  IDV_BASIC_INFO_SUBMITTED_FORM = 'IdV: basic info form submitted'.freeze
  IDV_BASIC_INFO_SUBMITTED_VENDOR = 'IdV: basic info vendor submitted'.freeze
  IDV_CANCELLATION = 'IdV: cancellation visited'.freeze
  IDV_CANCELLATION_CONFIRMED = 'IdV: cancellation confirmed'.freeze
  IDV_COME_BACK_LATER_VISIT = 'IdV: come back later visited'.freeze
  IDV_MAX_ATTEMPTS_EXCEEDED = 'IdV: max attempts exceeded'.freeze
  IDV_FINAL = 'IdV: final resolution'.freeze
  IDV_FORGOT_PASSWORD = 'IdV: forgot password visited'.freeze
  IDV_FORGOT_PASSWORD_CONFIRMED = 'IdV: forgot password confirmed'.freeze
  IDV_INTRO_VISIT = 'IdV: intro visited'.freeze
  IDV_JURISDICTION_VISIT = 'IdV: jurisdiction visited'.freeze
  IDV_JURISDICTION_FORM = 'IdV: jurisdiction form submitted'.freeze
  IDV_PHONE_CONFIRMATION_FORM = 'IdV: phone confirmation form'.freeze
  IDV_PHONE_CONFIRMATION_VENDOR = 'IdV: phone confirmation vendor'.freeze
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_ATTEMPTS = 'Idv: Phone OTP attempts rate limited'.freeze
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_LOCKED_OUT = 'Idv: Phone OTP rate limited user'.freeze
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_SENDS = 'Idv: Phone OTP sends rate limited'.freeze
  IDV_PHONE_CONFIRMATION_OTP_RESENT = 'IdV: phone confirmation otp resent'.freeze
  IDV_PHONE_CONFIRMATION_OTP_SENT = 'IdV: phone confirmation otp sent'.freeze
  IDV_PHONE_CONFIRMATION_OTP_SUBMITTED = 'IdV: phone confirmation otp submitted'.freeze
  IDV_PHONE_CONFIRMATION_OTP_VISIT = 'IdV: phone confirmation otp visited'.freeze
  IDV_PHONE_OTP_DELIVERY_SELECTION_SUBMITTED = 'IdV: Phone OTP Delivery Selection Submitted'.freeze
  IDV_PHONE_OTP_DELIVERY_SELECTION_VISIT = 'IdV: Phone OTP delivery Selection Visited'.freeze
  IDV_PHONE_RECORD_VISIT = 'IdV: phone of record visited'.freeze
  IDV_REVIEW_COMPLETE = 'IdV: review complete'.freeze
  IDV_REVIEW_VISIT = 'IdV: review info visited'.freeze
  IDV_USPS_ADDRESS_SUBMITTED = 'IdV: USPS address submitted'.freeze
  IDV_VERIFICATION_ATTEMPT_CANCELLED = 'IdV: verification attempt cancelled'.freeze
  INVALID_AUTHENTICITY_TOKEN = 'Invalid Authenticity Token'.freeze
  LOGOUT_INITIATED = 'Logout Initiated'.freeze
  MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'.freeze
  MULTI_FACTOR_AUTH_ENTER_OTP_VISIT = 'Multi-Factor Authentication: enter OTP visited'.freeze
  MULTI_FACTOR_AUTH_ENTER_PIV_CAC = 'Multi-Factor Authentication: enter PIV CAC visited'.freeze
  MULTI_FACTOR_AUTH_ENTER_TOTP_VISIT = 'Multi-Factor Authentication: enter TOTP visited'.freeze
  MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT = 'Multi-Factor Authentication: enter personal key visited'.freeze
  MULTI_FACTOR_AUTH_ENTER_BACKUP_CODE_VISIT = 'Multi-Factor Authentication: enter backup code visited'.freeze
  MULTI_FACTOR_AUTH_MAX_ATTEMPTS = 'Multi-Factor Authentication: max attempts reached'.freeze
  MULTI_FACTOR_AUTH_OPTION_LIST = 'Multi-Factor Authentication: option list'.freeze
  MULTI_FACTOR_AUTH_OPTION_LIST_VISIT = 'Multi-Factor Authentication: option list visited'.freeze
  MULTI_FACTOR_AUTH_PHONE_SETUP = 'Multi-Factor Authentication: phone setup'.freeze
  MULTI_FACTOR_AUTH_MAX_SENDS = 'Multi-Factor Authentication: max otp sends reached'.freeze
  MULTI_FACTOR_AUTH_SETUP = 'Multi-Factor Authentication Setup'.freeze
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
  PASSWORD_RESET_VISIT = 'Password Reset: Email Form Visited'.freeze
  PERSONAL_KEY_VIEWED = 'Personal Key Viewed'.freeze
  PHONE_CHANGE_REQUESTED = 'Phone Number Change: requested'.freeze
  PHONE_DELETION_REQUESTED = 'Phone Number Deletion: requested'.freeze
  PIV_CAC_LOGIN = 'PIV/CAC Login'.freeze
  PROFILE_ENCRYPTION_INVALID = 'Profile Encryption: Invalid'.freeze
  PROFILE_PERSONAL_KEY_CREATE = 'Profile: Created new personal key'.freeze
  RATE_LIMIT_TRIGGERED = 'Rate Limit Triggered'.freeze
  RESPONSE_TIMED_OUT = 'Response Timed Out'.freeze
  REMEMBERED_DEVICE_USED_FOR_AUTH = 'Remembered device used for authentication'.freeze
  BACKUP_CODE_CREATED = 'Backup Code Created'.freeze
  BACKUP_CODE_DELETED = 'Backup Code Delete'.freeze
  BACKUP_CODE_SETUP_VISIT = 'Backup Code Setup Visited'.freeze
  BACKUP_CODE_SETUP_SUBMITTED = 'Backup Code Setup submitted'.freeze
  SAML_AUTH = 'SAML Auth'.freeze
  SESSION_TIMED_OUT = 'Session Timed Out'.freeze
  SIGN_IN_PAGE_VISIT = 'Sign in page visited'.freeze
  SP_REDIRECT_INITIATED = 'SP redirect initiated'.freeze
  TOTP_SETUP_VISIT = 'TOTP Setup Visited'.freeze
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'.freeze
  TWILIO_PHONE_VALIDATION_FAILED = 'Twilio Phone Validation Failed'.freeze
  TWILIO_SMS_INBOUND_MESSAGE_RECEIVED = 'Twilio SMS Inbound Message Received'.freeze
  TWILIO_SMS_INBOUND_MESSAGE_VALIDATION_FAILED = 'Twilio SMS Inbound Validation Failed'.freeze
  USER_MARKED_AUTHED = 'User marked authenticated'.freeze
  USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT = 'User registration: agency handoff visited'.freeze
  USER_REGISTRATION_CANCELLATION = 'User registration: cancellation visited'.freeze
  USER_REGISTRATION_COMPLETE = 'User registration: complete'.freeze
  USER_REGISTRATION_EMAIL = 'User Registration: Email Submitted'.freeze
  USER_REGISTRATION_EMAIL_CONFIRMATION = 'User Registration: Email Confirmation'.freeze
  USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND = 'User Registration: Email Confirmation requested due to invalid token'.freeze
  USER_REGISTRATION_ENTER_EMAIL_VISIT = 'User Registration: enter email visited'.freeze
  USER_REGISTRATION_INTRO_VISIT = 'User Registration: intro visited'.freeze
  USER_REGISTRATION_2FA_SETUP = 'User Registration: 2FA Setup'.freeze
  USER_REGISTRATION_2FA_SETUP_VISIT = 'User Registration: 2FA Setup visited'.freeze
  USER_REGISTRATION_PHONE_SETUP_VISIT = 'User Registration: phone setup visited'.freeze
  USER_REGISTRATION_PERSONAL_KEY_VISIT = 'User Registration: personal key visited'.freeze
  USER_REGISTRATION_PIV_CAC_DISABLED = 'User Registration: piv cac disabled'.freeze
  USER_REGISTRATION_PIV_CAC_SETUP_VISIT = 'User Registration: piv cac setup visited'.freeze
  WEBAUTHN_DELETED = 'WebAuthn Deleted'.freeze
  WEBAUTHN_SETUP_VISIT = 'WebAuthn Setup Visited'.freeze
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/LineLength
# rubocop:enable Metrics/ClassLength
