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
  USER_REGISTRATION_CANCELLATION = 'User registration: cancellation visited'
  USER_REGISTRATION_COMPLETE = 'User registration: complete'
  USER_REGISTRATION_EMAIL = 'User Registration: Email Submitted'
  USER_REGISTRATION_EMAIL_CONFIRMATION = 'User Registration: Email Confirmation'
  USER_REGISTRATION_EMAIL_CONFIRMATION_RESEND = 'User Registration: Email Confirmation requested due to invalid token'
end
# rubocop:enable Layout/LineLength
