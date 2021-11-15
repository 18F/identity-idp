class Analytics
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
    mfa_event_type = (attributes[:success] ? 'success' : 'fail')
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

  # rubocop:disable Layout/LineLength
  ACCOUNT_RESET = 'Account Reset'.freeze
  ACCOUNT_DELETE_SUBMITTED = 'Account Delete submitted'.freeze
  ACCOUNT_DELETE_VISITED = 'Account Delete visited'.freeze
  ACCOUNT_DELETION = 'Account Deletion Requested'.freeze
  ACCOUNT_RESET_VISIT = 'Account deletion and reset visited'.freeze
  ACCOUNT_VERIFICATION_SUBMITTED = 'Account verification submitted'
  ACCOUNT_VERIFICATION_VISITED = 'Account verification visited'
  ACCOUNT_VISIT = 'Account Page Visited'.freeze
  ADD_EMAIL = 'Add Email: Email Submitted'.freeze
  ADD_EMAIL_CONFIRMATION = 'Add Email: Email Confirmation'.freeze
  ADD_EMAIL_CONFIRMATION_RESEND = 'Add Email: Email Confirmation requested due to invalid token'.freeze
  ADD_EMAIL_VISIT = 'Add Email: enter email visited'.freeze
  AUTHENTICATION_CONFIRMATION = 'Authentication Confirmation'.freeze
  DOC_AUTH = 'Doc Auth'.freeze # visited or submitted is appended
  DOC_AUTH_ASYNC = 'Doc Auth Async'.freeze
  DOC_AUTH_WARNING = 'Doc Auth Warning'.freeze
  EMAIL_AND_PASSWORD_AUTH = 'Email and Password Authentication'.freeze
  EMAIL_DELETION_REQUEST = 'Email Deletion Requested'.freeze
  EMAIL_LANGUAGE_VISITED = 'Email Language: Visited'.freeze
  EMAIL_LANGUAGE_UPDATED = 'Email Language: Updated'.freeze
  EVENT_DISAVOWAL = 'Event disavowal visited'.freeze
  EVENT_DISAVOWAL_PASSWORD_RESET = 'Event disavowal password reset'.freeze
  EVENT_DISAVOWAL_TOKEN_INVALID = 'Event disavowal token invalid'.freeze
  EVENTS_VISIT = 'Events Page Visited'.freeze
  FORGET_ALL_BROWSERS_SUBMITTED = 'Forget All Browsers Submitted'.freeze
  FORGET_ALL_BROWSERS_VISITED = 'Forget All Browsers Visited'.freeze
  IDV_ADDRESS_VISIT = 'IdV: address visited'.freeze
  IDV_ADDRESS_SUBMITTED = 'IdV: address submitted'.freeze
  IDV_BASIC_INFO_VISIT = 'IdV: basic info visited'.freeze
  IDV_BASIC_INFO_SUBMITTED_FORM = 'IdV: basic info form submitted'.freeze
  IDV_BASIC_INFO_SUBMITTED_VENDOR = 'IdV: basic info vendor submitted'.freeze
  IDV_CANCELLATION = 'IdV: cancellation visited'.freeze
  IDV_CANCELLATION_CONFIRMED = 'IdV: cancellation confirmed'.freeze
  IDV_COME_BACK_LATER_VISIT = 'IdV: come back later visited'.freeze
  IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_FORM = 'IdV: doc auth image upload form submitted'.freeze
  IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR = 'IdV: doc auth image upload vendor submitted'.freeze
  IDV_DOC_AUTH_SUBMITTED_PII_VALIDATION = 'IdV: doc auth image upload vendor pii validation'.freeze
  IDV_DOWNLOAD_PERSONAL_KEY = 'IdV: download personal key'.freeze
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
  IDV_START_OVER = 'IdV: start over'.freeze
  IDV_GPO_ADDRESS_LETTER_REQUESTED = 'IdV: USPS address letter requested'.freeze
  IDV_GPO_ADDRESS_SUBMITTED = 'IdV: USPS address submitted'.freeze
  IDV_GPO_ADDRESS_VISITED = 'IdV: USPS address visited'.freeze
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
  PENDING_ACCOUNT_RESET_CANCELLED = 'Pending account reset cancelled'.freeze
  PENDING_ACCOUNT_RESET_VISITED = 'Pending account reset visited'.freeze
  PERSONAL_KEY_ALERT_ABOUT_SIGN_IN = 'Personal key: Alert user about sign in'.freeze
  PERSONAL_KEY_REACTIVATION = 'Personal key reactivation: Account reactivated with personal key'.freeze
  PERSONAL_KEY_REACTIVATION_SIGN_IN = 'Personal key reactivation: Account reactivated with personal key as MFA'.freeze
  PERSONAL_KEY_REACTIVATION_SUBMITTED = 'Personal key reactivation: Personal key form submitted'.freeze
  PERSONAL_KEY_REACTIVATION_VISITED = 'Personal key reactivation: Personal key form visitted'.freeze
  PERSONAL_KEY_VIEWED = 'Personal Key Viewed'.freeze
  PHONE_CHANGE_SUBMITTED = 'Phone Number Change: Form submitted'.freeze
  PHONE_CHANGE_VIEWED = 'Phone Number Change: Visited'.freeze
  PHONE_DELETION = 'Phone Number Deletion: Submitted'.freeze
  PIV_CAC_LOGIN = 'PIV/CAC Login'.freeze
  PROFILE_ENCRYPTION_INVALID = 'Profile Encryption: Invalid'.freeze
  PROFILE_PERSONAL_KEY_CREATE = 'Profile: Created new personal key'.freeze
  PROFILE_PERSONAL_KEY_CREATE_NOTIFICATIONS = 'Profile: Created new personal key notifications'.freeze
  PROOFING_ADDRESS_TIMEOUT = 'Proofing Address Timeout'.freeze
  PROOFING_DOCUMENT_TIMEOUT = 'Proofing Document Timeout'.freeze
  PROOFING_RESOLUTION_TIMEOUT = 'Proofing Resolution Timeout'.freeze
  RATE_LIMIT_TRIGGERED = 'Rate Limit Triggered'.freeze
  RESPONSE_TIMED_OUT = 'Response Timed Out'.freeze
  REMEMBERED_DEVICE_USED_FOR_AUTH = 'Remembered device used for authentication'.freeze
  RETURN_TO_SP_CANCEL = 'Return to SP: Cancelled'.freeze
  RETURN_TO_SP_FAILURE_TO_PROOF = 'Return to SP: Failed to proof'.freeze
  RULES_OF_USE_VISIT = 'Rules Of Use Visited'.freeze
  RULES_OF_USE_SUBMITTED = 'Rules Of Use Submitted'.freeze
  SECURITY_EVENT_RECEIVED = 'RISC: Security event received'.freeze
  SP_REVOKE_CONSENT_REVOKED = 'SP Revoke Consent: Revoked'.freeze
  SP_REVOKE_CONSENT_VISITED = 'SP Revoke Consent: Visited'.freeze
  SP_HANDOFF_BOUNCED_DETECTED = 'SP handoff bounced detected'.freeze
  SP_HANDOFF_BOUNCED_VISIT = 'SP handoff bounced visited'.freeze
  SP_INACTIVE_VISIT = 'SP inactive visited'.freeze
  BACKUP_CODE_CREATED = 'Backup Code Created'.freeze
  BACKUP_CODE_DELETED = 'Backup Code Delete'.freeze
  BACKUP_CODE_SETUP_VISIT = 'Backup Code Setup Visited'.freeze
  BACKUP_CODE_SETUP_SUBMITTED = 'Backup Code Setup submitted'.freeze
  SAML_AUTH = 'SAML Auth'.freeze
  SESSION_TIMED_OUT = 'Session Timed Out'.freeze
  SESSION_KEPT_ALIVE = 'Session Kept Alive'.freeze
  SESSION_TOTAL_DURATION_TIMEOUT = 'User Maximum Session Length Exceeded'.freeze
  SIGN_IN_PAGE_VISIT = 'Sign in page visited'.freeze
  SP_REDIRECT_INITIATED = 'SP redirect initiated'.freeze
  TELEPHONY_OTP_SENT = 'Telephony: OTP sent'.freeze
  THROTTLER_RATE_LIMIT_TRIGGERED = 'Throttler Rate Limit Triggered'.freeze
  TOTP_SETUP_VISIT = 'TOTP Setup Visited'.freeze
  TOTP_USER_DISABLED = 'TOTP: User Disabled TOTP'.freeze
  OTP_PHONE_VALIDATION_FAILED = 'Twilio Phone Validation Failed'.freeze
  OTP_SMS_INBOUND_MESSAGE_RECEIVED = 'Twilio SMS Inbound Message Received'.freeze
  OTP_SMS_INBOUND_MESSAGE_VALIDATION_FAILED = 'Twilio SMS Inbound Validation Failed'.freeze
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
  VENDOR_OUTAGE = 'Vendor Outage'.freeze
  WEBAUTHN_DELETED = 'WebAuthn Deleted'.freeze
  WEBAUTHN_SETUP_VISIT = 'WebAuthn Setup Visited'.freeze
end
# rubocop:enable Layout/LineLength
