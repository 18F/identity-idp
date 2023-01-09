require 'core_extensions/string/permit'

class ApplicationController < ActionController::Base
  String.include CoreExtensions::String::Permit
  include VerifyProfileConcern
  include LocaleHelper
  include VerifySpAttributesConcern
  include EffectiveUser

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::Redirecting::UnsafeRedirectError, with: :unsafe_redirect_error
  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_auth_token
  rescue_from ActionController::UnknownFormat, with: :render_not_found
  rescue_from ActionView::MissingTemplate, with: :render_not_acceptable
  [
    ActiveRecord::ConnectionTimeoutError,
    PG::ConnectionBad, # raised when a Postgres connection times out
    Rack::Timeout::RequestTimeoutException,
    Redis::BaseConnectionError,
  ].each do |error|
    rescue_from error, with: :render_timeout
  end

  helper_method :decorated_session, :reauthn?, :user_fully_authenticated?

  prepend_before_action :add_new_relic_trace_attributes
  prepend_before_action :session_expires_at
  prepend_before_action :set_locale
  before_action :disable_caching
  before_action :cache_issuer_in_cookie

  def session_expires_at
    return if @skip_session_expiration || @skip_session_load
    now = Time.zone.now
    session[:session_started_at] = now if session[:session_started_at].nil?
    session[:session_expires_at] = now + Devise.timeout_in
    session[:pinged_at] ||= now
    redirect_on_timeout
  end

  # for lograge
  def append_info_to_payload(payload)
    payload[:user_id] = analytics_user.uuid unless @skip_session_load

    payload[:git_sha] = IdentityConfig::GIT_SHA
    if IdentityConfig::GIT_TAG.present?
      payload[:git_tag] = IdentityConfig::GIT_TAG
    else
      payload[:git_branch] = IdentityConfig::GIT_BRANCH
    end

    payload
  end

  attr_writer :analytics

  def analytics
    return @analytics if @analytics
    @analytics =
      Analytics.new(
        user: analytics_user,
        request: request,
        sp: current_sp&.issuer,
        session: session,
        ahoy: ahoy,
      )
  end

  def analytics_user
    effective_user || AnonymousUser.new
  end

  def irs_attempts_api_tracker
    @irs_attempts_api_tracker ||= IrsAttemptsApi::Tracker.new(
      session_id: irs_attempts_api_session_id,
      request: request,
      user: effective_user,
      sp: current_sp,
      cookie_device_uuid: cookies[:device],
      sp_request_uri: decorated_session.request_url_params[:redirect_uri],
      enabled_for_session: irs_attempt_api_enabled_for_session?,
      analytics: analytics,
    )
  end

  def irs_attempt_api_enabled_for_session?
    current_sp&.irs_attempts_api_enabled?
  end

  def irs_attempts_api_session_id
    decorated_session.irs_attempts_api_session_id
  end

  def user_event_creator
    @user_event_creator ||= UserEventCreator.new(request: request, current_user: current_user)
  end
  delegate :create_user_event, :create_user_event_with_disavowal, to: :user_event_creator
  delegate :remember_device_default, to: :decorated_session

  def decorated_session
    @decorated_session ||= DecoratedSession.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    ).call
  end

  def default_url_options
    { locale: locale_url_param, host: IdentityConfig.store.domain_name }
  end

  def sign_out(*args)
    request.cookie_jar.delete('ahoy_visit')
    super
  end

  def context
    user_session[:context] || UserSessionContext::AUTHENTICATION_CONTEXT
  end

  def current_sp
    @current_sp ||= sp_from_sp_session || sp_from_request_id
  end

  private

  # These attributes show up in New Relic traces for all requests.
  # https://docs.newrelic.com/docs/agents/manage-apm-agents/agent-data/collect-custom-attributes
  def add_new_relic_trace_attributes
    ::NewRelic::Agent.add_custom_attributes(amzn_trace_id: amzn_trace_id)
  end

  def amzn_trace_id
    request.headers['X-Amzn-Trace-Id']
  end

  def disable_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
  end

  def cache_issuer_in_cookie
    return if @skip_session_load
    cookies[:sp_issuer] = if current_sp.nil?
                            nil
                          else
                            {
                              value: current_sp.issuer,
                              expires: IdentityConfig.store.session_timeout_in_minutes.minutes,
                            }
                          end
  end

  def redirect_on_timeout
    return unless params[:timeout]

    unless current_user
      flash[:info] = t(
        'notices.session_cleared',
        minutes: IdentityConfig.store.session_timeout_in_minutes,
      )
    end
    begin
      redirect_to url_for(permitted_timeout_params)
    rescue ActionController::UrlGenerationError # binary data in params cause redirect to throw this
      head :bad_request
    end
  end

  def permitted_timeout_params
    params.permit(:request_id)
  end

  def sp_from_sp_session
    ServiceProvider.find_by(issuer: sp_session[:issuer]) if sp_session[:issuer].present?
  end

  def sp_from_request_id
    if service_provider_request.issuer.present?
      ServiceProvider.find_by(issuer: service_provider_request.issuer)
    end
  end

  def sp_from_request_issuer_logout
    return if action_name != 'logout'
    if saml_request&.service_provider&.identifier.present?
      ServiceProvider.find_by(issuer: saml_request.service_provider.identifier)
    end
  end

  def service_provider_request
    @service_provider_request ||= ServiceProviderRequestProxy.from_uuid(params[:request_id])
  end

  def add_piv_cac_setup_url
    session[:needs_to_setup_piv_cac_after_sign_in] ? login_add_piv_cac_prompt_url : nil
  end

  def service_provider_mfa_setup_url
    service_provider_mfa_policy.user_needs_sp_auth_method_setup? ?
      authentication_methods_setup_url : nil
  end

  def fix_broken_personal_key_url
    return if !current_user.broken_personal_key?

    flash[:info] = t('account.personal_key.needs_new')

    pii_unlocked = Pii::Cacher.new(current_user, user_session).exists_in_session?

    if pii_unlocked
      cacher = Pii::Cacher.new(current_user, user_session)
      profile = current_user.active_profile
      user_session[:personal_key] = profile.encrypt_recovery_pii(cacher.fetch)
      profile.save!

      analytics.broken_personal_key_regenerated

      manage_personal_key_url
    else
      user_session[:needs_new_personal_key] = true

      capture_password_url
    end
  end

  def after_sign_in_path_for(_user)
    service_provider_mfa_setup_url ||
      add_piv_cac_setup_url ||
      fix_broken_personal_key_url ||
      user_session.delete(:stored_location) ||
      sp_session_request_url_with_updated_params ||
      signed_in_url
  end

  def signed_in_url
    user_fully_authenticated? ? account_or_verify_profile_url : user_two_factor_authentication_url
  end

  def after_mfa_setup_path
    if needs_completion_screen_reason
      sign_up_completed_url
    elsif user_needs_to_reactivate_account?
      reactivate_account_url
    else
      session[:account_redirect_path] || after_sign_in_path_for(current_user)
    end
  end

  def user_needs_to_reactivate_account?
    return false if current_user.decorate.password_reset_profile.blank?
    return false if pending_profile_newer_than_password_reset_profile?
    sp_session[:ial2] == true
  end

  def pending_profile_newer_than_password_reset_profile?
    return false if current_user.decorate.pending_profile.blank?
    return false if current_user.decorate.password_reset_profile.blank?
    current_user.decorate.pending_profile.created_at >
      current_user.decorate.password_reset_profile.updated_at
  end

  def reauthn_param
    params[:reauthn]
  end

  def invalid_auth_token(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.invalid_authenticity_token(
      controller: controller_info,
      user_signed_in: user_signed_in?,
    )
    flash[:error] = t('errors.general')
    redirect_back fallback_location: new_user_session_url, allow_other_host: false
  end

  def unsafe_redirect_error(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.unsafe_redirect_error(
      controller: controller_info,
      user_signed_in: user_signed_in?,
      referer: request.referer,
    )

    flash[:error] = t('errors.general')
    redirect_to new_user_session_url
  end

  def user_fully_authenticated?
    !reauthn? && user_signed_in? &&
      two_factor_enabled? &&
      session['warden.user.user.session'] &&
      !session['warden.user.user.session'].try(
        :[],
        TwoFactorAuthenticatable::NEED_AUTHENTICATION,
      )
  end

  def two_factor_kantara_enabled?
    return false if controller_path == 'additional_mfa_required'
    return false if user_session[:skip_kantara_req]
    IdentityConfig.store.kantara_2fa_phone_existing_user_restriction &&
      MfaContext.new(current_user).enabled_non_restricted_mfa_methods_count < 1
  end

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  def confirm_two_factor_authenticated(id = nil)
    return prompt_to_sign_in_with_request_id(id) if user_needs_new_session_with_request_id?(id)

    authenticate_user!(force: true)

    if !two_factor_enabled?
      return prompt_to_setup_mfa
    elsif !user_fully_authenticated?
      return prompt_to_verify_mfa
    elsif service_provider_mfa_policy.user_needs_sp_auth_method_setup?
      return prompt_to_setup_mfa
    elsif two_factor_kantara_enabled?
      return prompt_to_setup_non_restricted_mfa
    elsif service_provider_mfa_policy.user_needs_sp_auth_method_verification?
      return prompt_to_verify_sp_required_mfa
    end

    enforce_total_session_duration_timeout

    true
  end

  def enforce_total_session_duration_timeout
    return sign_out_with_timeout_error if session_total_duration_expired?
    ensure_user_session_has_created_at
  end

  def sign_out_with_timeout_error
    analytics.session_total_duration_timeout
    sign_out
    flash[:info] = t('devise.failure.timeout')
    redirect_to root_url
  end

  def ensure_user_session_has_created_at
    return if user_session.nil? || user_session[:created_at].present?
    user_session[:created_at] = Time.zone.now
  end

  def session_total_duration_expired?
    session_created_at = user_session&.dig(:created_at)
    return if session_created_at.blank?
    session_created_at = Time.zone.parse(session_created_at.to_s)
    timeout_in_minutes = IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes
    (session_created_at + timeout_in_minutes) < Time.zone.now
  end

  def prompt_to_sign_in_with_request_id(request_id)
    redirect_to new_user_session_url(request_id: request_id)
  end

  def prompt_to_setup_mfa
    redirect_to authentication_methods_setup_url
  end

  def prompt_to_verify_mfa
    redirect_to user_two_factor_authentication_url
  end

  def prompt_to_verify_sp_required_mfa
    redirect_to sp_required_mfa_verification_url
  end

  def prompt_to_setup_non_restricted_mfa
    redirect_to login_additional_mfa_required_url
  end

  def sp_required_mfa_verification_url
    return login_two_factor_piv_cac_url if service_provider_mfa_policy.piv_cac_required?

    if TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled? && !mobile?
      login_two_factor_piv_cac_url
    elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?
      login_two_factor_webauthn_url
    else
      login_two_factor_piv_cac_url
    end
  end

  def user_needs_new_session_with_request_id?(id)
    !user_signed_in? && id.present?
  end

  def two_factor_enabled?
    MfaPolicy.new(current_user).two_factor_enabled?
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def skip_session_load
    @skip_session_load = true
  end

  def set_locale
    I18n.locale = LocaleChooser.new(params[:locale], request).locale
  end

  def sp_session_ial
    sp_session[:ial].presence || 1
  end

  def mfa_policy
    @mfa_policy ||= MfaPolicy.new(current_user)
  end

  def service_provider_mfa_policy
    @service_provider_mfa_policy ||= ServiceProviderMfaPolicy.new(
      user: current_user,
      service_provider: sp_from_sp_session,
      auth_method: user_session[:auth_method],
      aal_level_requested: sp_session[:aal_level_requested],
      piv_cac_requested: sp_session[:piv_cac_requested],
      phishing_resistant_requested: sp_session[:phishing_resistant_requested],
    )
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def sp_session_request_url_with_updated_params
    # Temporarily place SAML route update behind a feature flag
    if IdentityConfig.store.saml_internal_post
      return unless sp_session[:request_url].present?
      request_url = URI(sp_session[:request_url])
      url = if request_url.path.match?('saml')
              complete_saml_url
            else
              # Login.gov redirects to the orginal request_url after a user authenticates
              # replace prompt=login with prompt=select_account to prevent sign_out
              # which should only ever occur once when the user
              # lands on Login.gov with prompt=login
              sp_session[:request_url]&.gsub('prompt=login', 'prompt=select_account')
            end
    else
      url = sp_session[:request_url]&.gsub('prompt=login', 'prompt=select_account')
    end

    # If the user has changed the locale, we should preserve that as well
    if url && locale_url_param && UriService.params(url)[:locale] != locale_url_param
      UriService.add_params(url, locale: locale_url_param)
    else
      url
    end
  end

  def render_not_found
    respond_to do |format|
      format.json do
        render json: { error: "The page you were looking for doesn't exist" }, status: :not_found
      end
      format.any do
        render template: 'pages/page_not_found', layout: false, status: :not_found, formats: :html
      end
    end
  end

  def render_not_acceptable
    render template: 'pages/not_acceptable', layout: false, status: :not_acceptable, formats: :html
  end

  def render_timeout(exception)
    analytics.response_timed_out(**analytics_exception_info(exception))
    if exception.instance_of?(Rack::Timeout::RequestTimeoutException)
      NewRelic::Agent.notice_error(exception)
    end
    render template: 'pages/page_took_too_long',
           layout: false, status: :service_unavailable, formats: :html
  end

  def render_full_width(template, **opts)
    render template, **opts, layout: 'base'
  end

  def analytics_exception_info(exception)
    {
      backtrace: Rails.backtrace_cleaner.send(:filter, exception.backtrace),
      exception_message: exception.to_s,
      exception_class: exception.class.name,
    }
  end

  def mobile?
    BrowserCache.parse(request.user_agent).mobile?
  end

  def user_is_banned?
    return false unless user_signed_in?
    BannedUserResolver.new(current_user).banned_for_sp?(issuer: current_sp&.issuer)
  end

  def handle_banned_user
    return unless user_is_banned?
    analytics.banned_user_redirect
    sign_out
    redirect_to banned_user_url
  end
end
