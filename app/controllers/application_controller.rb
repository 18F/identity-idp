require 'core_extensions/string/permit'

class ApplicationController < ActionController::Base
  String.include CoreExtensions::String::Permit
  include UserSessionContext
  include VerifyProfileConcern
  include LocaleHelper
  include VerifySpAttributesConcern

  FLASH_KEYS = %w[error info success warning other].freeze
  FLASH_KEY_MAP = { 'notice' => 'info', 'alert' => 'error' }.freeze

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_auth_token
  rescue_from ActionController::UnknownFormat, with: :render_not_found
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
    now = Time.zone.now
    session[:session_expires_at] = now + Devise.timeout_in
    session[:pinged_at] ||= now
    redirect_on_timeout
  end

  # for lograge
  def append_info_to_payload(payload)
    payload[:user_id] = analytics_user.uuid unless @skip_session_load
  end

  attr_writer :analytics

  def analytics
    @analytics ||=
      Analytics.new(user: analytics_user, request: request, sp: current_sp&.issuer, ahoy: ahoy)
  end

  def analytics_user
    warden.user || AnonymousUser.new
  end

  def user_event_creator
    @user_event_creator ||= UserEventCreator.new(request: request, current_user: current_user)
  end
  delegate :create_user_event, :create_user_event_with_disavowal, to: :user_event_creator
  delegate :remember_device_default, to: :decorated_session

  def decorated_session
    @_decorated_session ||= DecoratedSession.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    ).call
  end

  def default_url_options
    { locale: locale_url_param, host: AppConfig.env.domain_name }
  end

  def sign_out(*args)
    request.cookie_jar.delete('ahoy_visit')
    super
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
    cookies[:sp_issuer] = if current_sp.nil?
                            nil
                          else
                            {
                              value: current_sp.issuer,
                              expires: AppConfig.env.issuer_cookie_expiration,
                            }
                          end
  end

  def redirect_on_timeout
    return unless params[:timeout]

    unless current_user
      flash[:info] = t('notices.session_cleared', minutes: AppConfig.env.session_timeout_in_minutes)
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

  def current_sp
    @current_sp ||= sp_from_sp_session || sp_from_request_id || sp_from_request_issuer_logout
  end

  def sp_from_sp_session
    sp = ServiceProvider.from_issuer(sp_session[:issuer])
    sp if sp.is_a? ServiceProvider
  end

  def sp_from_request_id
    sp = ServiceProvider.from_issuer(service_provider_request.issuer)
    sp if sp.is_a? ServiceProvider
  end

  def sp_from_request_issuer_logout
    return if action_name != 'logout'
    issuer_sp = ServiceProvider.from_issuer(saml_request&.service_provider&.identifier)
    issuer_sp if issuer_sp.is_a? ServiceProvider
  end

  def service_provider_request
    @service_provider_request ||= ServiceProviderRequestProxy.from_uuid(params[:request_id])
  end

  def add_piv_cac_setup_url
    session[:needs_to_setup_piv_cac_after_sign_in] ? login_add_piv_cac_prompt_url : nil
  end

  def service_provider_mfa_setup_url
    service_provider_mfa_policy.user_needs_sp_auth_method_setup? ? two_factor_options_url : nil
  end

  def after_sign_in_path_for(_user)
    service_provider_mfa_setup_url || add_piv_cac_setup_url ||
      user_session.delete(:stored_location) || sp_session_request_url_without_prompt_login ||
      signed_in_url
  end

  def signed_in_url
    user_fully_authenticated? ? account_or_verify_profile_url : user_two_factor_authentication_url
  end

  def after_mfa_setup_path
    if needs_completions_screen?
      sign_up_completed_url
    elsif user_needs_to_reactivate_account?
      reactivate_account_url
    else
      session[:account_redirect_path] || after_sign_in_path_for(current_user)
    end
  end

  def user_needs_to_reactivate_account?
    return false if current_user.decorate.password_reset_profile.blank?
    sp_session[:ial2] == true
  end

  def reauthn_param
    params[:reauthn]
  end

  def invalid_auth_token(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.track_event(
      Analytics::INVALID_AUTHENTICITY_TOKEN,
      controller: controller_info,
      user_signed_in: user_signed_in?,
    )
    flash[:error] = t('errors.invalid_authenticity_token')
    redirect_back fallback_location: new_user_session_url
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

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  def confirm_two_factor_authenticated(id = nil)
    return total_session_duration_timeout if session_total_duration_expired?
    return prompt_to_sign_in_with_request_id(id) if user_needs_new_session_with_request_id?(id)
    authenticate_user!(force: true)
    return prompt_to_setup_mfa unless two_factor_enabled?
    return prompt_to_verify_mfa unless user_fully_authenticated?
    return prompt_to_setup_mfa if service_provider_mfa_policy.
                                  user_needs_sp_auth_method_setup?
    return prompt_to_verify_sp_required_mfa if service_provider_mfa_policy.
                                               user_needs_sp_auth_method_verification?
    ensure_user_session_has_created_at
    true
  end

  def total_session_duration_timeout
    sign_out
    flash[:info] = t('devise.failure.timeout')
    redirect_to root_url
  end

  def ensure_user_session_has_created_at
    session_created_at = user_session&.dig(:created_at)
    return if session_created_at.present?
    user_session[:created_at] = Time.zone.now
  end

  def session_total_duration_expired?
    session_created_at = user_session[:created_at]
    return if session_created_at.blank?
    session_created_at = Time.zone.parse(session_created_at)
    timeout_in_minutes = AppConfig.env.session_total_duration_timeout_in_minutes.to_i.minutes
    (session_created_at + timeout_in_minutes) < Time.zone.now
  end

  def prompt_to_sign_in_with_request_id(request_id)
    redirect_to new_user_session_url(request_id: request_id)
  end

  def prompt_to_setup_mfa
    redirect_to two_factor_options_url
  end

  def prompt_to_verify_mfa
    redirect_to user_two_factor_authentication_url
  end

  def prompt_to_verify_sp_required_mfa
    redirect_to sp_required_mfa_verification_url
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
    sp_session[:ial]
  end

  def sp_session_ial_1_or_2
    return 1 if sp_session[:ial].blank?
    sp_session[:ial] > 1 ? 2 : 1
  end

  def increment_monthly_auth_count
    return unless current_user&.id
    issuer = sp_session[:issuer]
    return if issuer.blank? || !first_auth_of_session?(issuer, sp_session_ial)
    MonthlySpAuthCount.increment(current_user.id, issuer, sp_session_ial_1_or_2)
  end

  def first_auth_of_session?(issuer, ial)
    authenticated_to_sp_token = "auth_counted_ial#{ial}_#{issuer}"
    authenticated_to_sp = user_session[authenticated_to_sp_token]
    return if authenticated_to_sp
    user_session[authenticated_to_sp_token] = true
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
    )
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def sp_session_request_url_without_prompt_login
    # login.gov redirects to the orginal request_url after a user authenticates
    # replace prompt=login with prompt=select_account to prevent sign_out
    # which should only every occur once when the user lands on login.gov with prompt=login
    url = sp_session[:request_url]
    url ? url.gsub('prompt=login', 'prompt=select_account') : nil
  end

  def render_not_found
    render template: 'pages/page_not_found', layout: false, status: :not_found, formats: :html
  end

  def render_timeout(exception)
    analytics.track_event(Analytics::RESPONSE_TIMED_OUT, analytics_exception_info(exception))
    if exception.class == Rack::Timeout::RequestTimeoutException
      NewRelic::Agent.notice_error(exception)
    end
    render template: 'pages/page_took_too_long',
           layout: false, status: :service_unavailable, formats: :html
  end

  def render_full_width(template, **opts)
    render template, **opts, layout: 'base'
  end

  def user_has_ial1_identity_for_issuer?(issuer)
    current_user.identities.where(service_provider: issuer, ial: 1).any?
  end

  def analytics_exception_info(exception)
    {
      backtrace: Rails.backtrace_cleaner.send(:filter, exception.backtrace),
      exception_message: exception.to_s,
      exception_class: exception.class.name,
    }
  end

  def add_sp_cost(token)
    Db::SpCost::AddSpCost.call(sp_session[:issuer].to_s, sp_session_ial_1_or_2, token)
  end

  def mobile?
    client = DeviceDetector.new(request.user_agent)
    client.device_type != 'desktop'
  end
end
