# frozen_string_literal: true

class Analytics
  include AnalyticsEvents

  def initialize(user:, request:, sp:, session:, ahoy: nil)
    @user = user
    @request = request
    @sp = sp
    @ahoy = ahoy || Ahoy::Tracker.new(request: request)
    @session = session
  end

  def track_event(event, attributes = {})
    attributes.delete(:pii_like_keypaths)
    update_session_events_and_paths_visited_for_analytics(event) if attributes[:success] != false
    analytics_hash = {
      event_properties: attributes.except(:user_id),
      new_event: first_event_this_session?,
      new_session_path: first_path_visit_this_session?,
      new_session_success_state: first_success_state_this_session?,
      success_state: success_state_token(event),
      path: request&.path,
      session_duration: session_duration,
      user_id: attributes[:user_id] || user.uuid,
      locale: I18n.locale,
    }

    analytics_hash.merge!(request_attributes) if request

    ahoy.track(event, analytics_hash)
    register_doc_auth_step_from_analytics_event(event, attributes)

    # Tag NewRelic APM trace with a handful of useful metadata
    # https://www.rubydoc.info/github/newrelic/rpm/NewRelic/Agent#add_custom_attributes-instance_method
    ::NewRelic::Agent.add_custom_attributes(
      user_id: analytics_hash[:user_id],
      user_ip: request&.remote_ip,
      service_provider: sp,
      event_name: event,
      git_sha: IdentityConfig::GIT_SHA,
    )
  end

  def update_session_events_and_paths_visited_for_analytics(event)
    @session[:paths_visited] ||= {}
    @session[:events] ||= {}
    @session[:success_states] ||= {}
    if request
      token = success_state_token(event)
      @session[:first_success_state] = !@session[:success_states].key?(token)
      @session[:success_states][token] = true
      @session[:first_path_visit] = !@session[:paths_visited].key?(request.path)
      @session[:paths_visited][request.path] = true
    end
    @session[:first_event] = !@session[:events].key?(event)
    @session[:events][event] = true
  end

  def first_path_visit_this_session?
    @session[:first_path_visit]
  end

  def first_success_state_this_session?
    @session[:first_success_state]
  end

  def success_state_token(event)
    "#{request&.env&.dig('REQUEST_METHOD')}|#{request&.path}|#{event}"
  end

  def first_event_this_session?
    @session[:first_event]
  end

  def register_doc_auth_step_from_analytics_event(event, attributes)
    return unless user && user.class != AnonymousUser
    success = attributes.blank? || attributes[:success] == 'success'
    Funnel::DocAuth::RegisterStepFromAnalyticsEvent.call(user.id, sp, event, success)
  end

  def track_mfa_submit_event(attributes)
    track_event(MULTI_FACTOR_AUTH, attributes)
    attributes[:success] ? 'success' : 'fail'
  end

  attr_reader :user, :request, :sp, :ahoy

  def request_attributes
    attributes = {
      user_ip: request.remote_ip,
      hostname: request.host,
      pid: Process.pid,
      service_provider: sp,
      trace_id: request.headers['X-Amzn-Trace-Id'],
    }

    attributes[:git_sha] = IdentityConfig::GIT_SHA
    if IdentityConfig::GIT_TAG.present?
      attributes[:git_tag] = IdentityConfig::GIT_TAG
    else
      attributes[:git_branch] = IdentityConfig::GIT_BRANCH
    end

    attributes.merge!(browser_attributes)
  end

  def browser
    @browser ||= BrowserCache.parse(request.user_agent)
  end

  def browser_attributes
    {
      user_agent: request.user_agent,
      browser_name: browser.name,
      browser_version: browser.full_version,
      browser_platform_name: browser.platform.name,
      browser_platform_version: browser.platform.version,
      browser_device_name: browser.device.name,
      browser_mobile: browser.device.mobile?,
      browser_bot: browser.bot?,
    }
  end

  def session_duration
    @session[:session_started_at].present? ? Time.zone.now - session_started_at : nil
  end

  def session_started_at
    value = @session[:session_started_at]
    return value unless value.is_a?(String)
    Time.zone.parse(value)
  end

  # rubocop:disable Layout/LineLength
  ACCOUNT_RESET_VISIT = 'Account deletion and reset visited'
  DOC_AUTH = 'Doc Auth' # visited or submitted is appended
  IDV_CANCELLATION = 'IdV: cancellation visited'
  IDV_CANCELLATION_GO_BACK = 'IdV: cancellation go back'
  IDV_CANCELLATION_CONFIRMED = 'IdV: cancellation confirmed'
  IDV_COME_BACK_LATER_VISIT = 'IdV: come back later visited'
  IDV_DOC_AUTH_EXCEPTION_VISITED = 'IdV: doc auth exception visited'
  IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM = 'IdV: doc auth image upload form submitted'
  IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR = 'IdV: doc auth image upload vendor submitted'
  IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION = 'IdV: doc auth image upload vendor pii validation'
  IDV_DOC_AUTH_WARNING_VISITED = 'IdV: doc auth warning visited'
  IDV_FINAL = 'IdV: final resolution'
  IDV_FORGOT_PASSWORD = 'IdV: forgot password visited'
  IDV_FORGOT_PASSWORD_CONFIRMED = 'IdV: forgot password confirmed'
  IDV_INTRO_VISIT = 'IdV: intro visited'
  IDV_JURISDICTION_VISIT = 'IdV: jurisdiction visited'
  IDV_JURISDICTION_FORM = 'IdV: jurisdiction form submitted'
  IDV_PERSONAL_KEY_VISITED = 'IdV: personal key visited'
  IDV_PERSONAL_KEY_SUBMITTED = 'IdV: personal key submitted'
  IDV_PHONE_CONFIRMATION_FORM = 'IdV: phone confirmation form'
  IDV_PHONE_CONFIRMATION_VENDOR = 'IdV: phone confirmation vendor'
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_ATTEMPTS = 'Idv: Phone OTP attempts rate limited'
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_LOCKED_OUT = 'Idv: Phone OTP rate limited user'
  IDV_PHONE_CONFIRMATION_OTP_RATE_LIMIT_SENDS = 'Idv: Phone OTP sends rate limited'
  IDV_PHONE_CONFIRMATION_OTP_RESENT = 'IdV: phone confirmation otp resent'
  IDV_PHONE_CONFIRMATION_OTP_SENT = 'IdV: phone confirmation otp sent'
  IDV_PHONE_OTP_DELIVERY_SELECTION_VISIT = 'IdV: Phone OTP delivery Selection Visited'
  IDV_PHONE_USE_DIFFERENT = 'IdV: use different phone number'
  IDV_PHONE_RECORD_VISIT = 'IdV: phone of record visited'
  IDV_REVIEW_COMPLETE = 'IdV: review complete'
  IDV_REVIEW_VISIT = 'IdV: review info visited'
  IDV_START_OVER = 'IdV: start over'
  IDV_GPO_ADDRESS_LETTER_REQUESTED = 'IdV: USPS address letter requested'
  IDV_GPO_ADDRESS_SUBMITTED = 'IdV: USPS address submitted'
  IDV_GPO_ADDRESS_VISITED = 'IdV: USPS address visited'
  IDV_GPO_VERIFICATION_SUBMITTED = 'IdV: GPO verification submitted' # Previously: "Account verification submitted"
  IDV_GPO_VERIFICATION_VISITED = 'IdV: GPO verification visited' # Previously: "Account verification visited"
  INVALID_AUTHENTICITY_TOKEN = 'Invalid Authenticity Token'
  LOGOUT_INITIATED = 'Logout Initiated'
  MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'
  MULTI_FACTOR_AUTH_ENTER_OTP_VISIT = 'Multi-Factor Authentication: enter OTP visited'
  MULTI_FACTOR_AUTH_ENTER_PIV_CAC = 'Multi-Factor Authentication: enter PIV CAC visited'
  MULTI_FACTOR_AUTH_ENTER_TOTP_VISIT = 'Multi-Factor Authentication: enter TOTP visited'
  MULTI_FACTOR_AUTH_ENTER_PERSONAL_KEY_VISIT = 'Multi-Factor Authentication: enter personal key visited'
  MULTI_FACTOR_AUTH_ENTER_BACKUP_CODE_VISIT = 'Multi-Factor Authentication: enter backup code visited'
  MULTI_FACTOR_AUTH_ENTER_WEBAUTHN_VISIT = 'Multi-Factor Authentication: enter webAuthn authentication visited'
  MULTI_FACTOR_AUTH_MAX_ATTEMPTS = 'Multi-Factor Authentication: max attempts reached'
  MULTI_FACTOR_AUTH_OPTION_LIST = 'Multi-Factor Authentication: option list'
  MULTI_FACTOR_AUTH_OPTION_LIST_VISIT = 'Multi-Factor Authentication: option list visited'
  MULTI_FACTOR_AUTH_PHONE_SETUP = 'Multi-Factor Authentication: phone setup'
  MULTI_FACTOR_AUTH_MAX_SENDS = 'Multi-Factor Authentication: max otp sends reached'
  MULTI_FACTOR_AUTH_SETUP = 'Multi-Factor Authentication Setup'
  OPENID_CONNECT_BEARER_TOKEN = 'OpenID Connect: bearer token authentication'
  OPENID_CONNECT_REQUEST_AUTHORIZATION = 'OpenID Connect: authorization request'
  OPENID_CONNECT_TOKEN = 'OpenID Connect: token'
  OTP_DELIVERY_SELECTION = 'OTP: Delivery Selection'
  PASSWORD_CHANGED = 'Password Changed'
  PASSWORD_CREATION = 'Password Creation'
  PASSWORD_MAX_ATTEMPTS = 'Password Max Attempts Reached'
  PASSWORD_RESET_EMAIL = 'Password Reset: Email Submitted'
  PASSWORD_RESET_PASSWORD = 'Password Reset: Password Submitted'
  PASSWORD_RESET_TOKEN = 'Password Reset: Token Submitted'
  PASSWORD_RESET_VISIT = 'Password Reset: Email Form Visited'
  PENDING_ACCOUNT_RESET_CANCELLED = 'Pending account reset cancelled'
  PENDING_ACCOUNT_RESET_VISITED = 'Pending account reset visited'
  PERSONAL_KEY_ALERT_ABOUT_SIGN_IN = 'Personal key: Alert user about sign in'
  PERSONAL_KEY_REACTIVATION = 'Personal key reactivation: Account reactivated with personal key'
  PERSONAL_KEY_REACTIVATION_SIGN_IN = 'Personal key reactivation: Account reactivated with personal key as MFA'
  PERSONAL_KEY_REACTIVATION_SUBMITTED = 'Personal key reactivation: Personal key form submitted'
  PERSONAL_KEY_REACTIVATION_VISITED = 'Personal key reactivation: Personal key form visitted'
  PERSONAL_KEY_VIEWED = 'Personal Key Viewed'
  PHONE_CHANGE_SUBMITTED = 'Phone Number Change: Form submitted'
  PHONE_CHANGE_VIEWED = 'Phone Number Change: Visited'
  PHONE_DELETION = 'Phone Number Deletion: Submitted'
  PIV_CAC_LOGIN = 'PIV/CAC Login'
  PROFILE_ENCRYPTION_INVALID = 'Profile Encryption: Invalid'
  PROOFING_RESOLUTION_RESULT_MISSING = 'Proofing Resolution Result Missing' # Previously "Proofing Resolution Timeout"
  RATE_LIMIT_TRIGGERED = 'Rate Limit Triggered'
  REPORT_REGISTERED_USERS_COUNT = 'Report Registered Users Count'
  REPORT_IAL1_USERS_LINKED_TO_SPS_COUNT = 'Report IAL1 Users Linked to SPs Count'
  REPORT_IAL2_USERS_LINKED_TO_SPS_COUNT= 'Report IAL2 Users Linked to SPs Count'
  REPORT_SP_USER_COUNTS = 'Report SP User Counts'
  RESPONSE_TIMED_OUT = 'Response Timed Out'
  REMEMBERED_DEVICE_USED_FOR_AUTH = 'Remembered device used for authentication'
  REMOTE_LOGOUT_INITIATED = 'Remote Logout initiated'
  RETURN_TO_SP_CANCEL = 'Return to SP: Cancelled'
  SP_HANDOFF_BOUNCED_DETECTED = 'SP handoff bounced detected'
  SP_HANDOFF_BOUNCED_VISIT = 'SP handoff bounced visited'
  SP_INACTIVE_VISIT = 'SP inactive visited'
  BACKUP_CODE_CREATED = 'Backup Code Created'
  BACKUP_CODE_DELETED = 'Backup Code Delete'
  BACKUP_CODE_SETUP_VISIT = 'Backup Code Setup Visited'
  BACKUP_CODE_SETUP_SUBMITTED = 'Backup Code Setup submitted'
  SAML_AUTH = 'SAML Auth'
  SESSION_TIMED_OUT = 'Session Timed Out'
  SESSION_KEPT_ALIVE = 'Session Kept Alive'
  SESSION_TOTAL_DURATION_TIMEOUT = 'User Maximum Session Length Exceeded'
  SIGN_IN_PAGE_VISIT = 'Sign in page visited'
  SMS_OPT_IN_SUBMITTED = 'SMS Opt-In: Submitted'
  SMS_OPT_IN_VISIT = 'SMS Opt-In: Visited'
  SP_REDIRECT_INITIATED = 'SP redirect initiated'
  TELEPHONY_OTP_SENT = 'Telephony: OTP sent'
  THROTTLER_RATE_LIMIT_TRIGGERED = 'Throttler Rate Limit Triggered'
  TOTP_SETUP_VISIT = 'TOTP Setup Visited'
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'
  OTP_PHONE_VALIDATION_FAILED = 'Twilio Phone Validation Failed'
  OTP_SMS_INBOUND_MESSAGE_RECEIVED = 'Twilio SMS Inbound Message Received'
  OTP_SMS_INBOUND_MESSAGE_VALIDATION_FAILED = 'Twilio SMS Inbound Validation Failed'
  USER_MARKED_AUTHED = 'User marked authenticated'
  USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT = 'User registration: agency handoff visited'
  USER_REGISTRATION_CANCELLATION = 'User registration: cancellation visited'
  USER_REGISTRATION_COMPLETE = 'User registration: complete'
  USER_REGISTRATION_EMAIL = 'User Registration: Email Submitted'
  USER_REGISTRATION_EMAIL_CONFIRMATION = 'User Registration: Email Confirmation'
  USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND = 'User Registration: Email Confirmation requested due to invalid token'
  USER_REGISTRATION_ENTER_EMAIL_VISIT = 'User Registration: enter email visited'
  USER_REGISTRATION_INTRO_VISIT = 'User Registration: intro visited'
  USER_REGISTRATION_2FA_SETUP = 'User Registration: 2FA Setup'
  USER_REGISTRATION_2FA_SETUP_VISIT = 'User Registration: 2FA Setup visited'
  USER_REGISTRATION_PHONE_SETUP_VISIT = 'User Registration: phone setup visited'
  USER_REGISTRATION_PERSONAL_KEY_VISIT = 'User Registration: personal key visited'
  USER_REGISTRATION_PIV_CAC_DISABLED = 'User Registration: piv cac disabled'
  USER_REGISTRATION_PIV_CAC_SETUP_VISIT = 'User Registration: piv cac setup visited'
  VENDOR_OUTAGE = 'Vendor Outage'
  WEBAUTHN_DELETED = 'WebAuthn Deleted'
  WEBAUTHN_SETUP_VISIT = 'WebAuthn Setup Visited'
end
# rubocop:enable Layout/LineLength
