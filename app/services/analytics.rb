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
    multi_factor_auth(
      **attributes,
      pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
    )
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
  DOC_AUTH = 'Doc Auth' # visited or submitted is appended
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
  REPORT_IAL2_USERS_LINKED_TO_SPS_COUNT = 'Report IAL2 Users Linked to SPs Count'
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
