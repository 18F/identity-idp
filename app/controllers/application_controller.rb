require 'core_extensions/string/permit'

class ApplicationController < ActionController::Base # rubocop:disable Metrics/ClassLength
  String.include CoreExtensions::String::Permit
  include UserSessionContext
  include VerifyProfileConcern
  include LocaleHelper
  include VerifySPAttributesConcern

  FLASH_KEYS = %w[alert error notice success warning].freeze

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

  skip_before_action :handle_two_factor_authentication

  # BAD BAD BAD
  before_action :log_action
  def log_action
    the_view = "#{controller_name}/#{action_name}"
    puts "Rendered #{the_view}"
    File.open("view_renders_in_test.txt", "a"){ |f| f.puts(the_view) }
  end

  def session_expires_at
    now = Time.zone.now
    session[:session_expires_at] = now + Devise.timeout_in
    session[:pinged_at] ||= now
    redirect_on_timeout
  end

  def append_info_to_payload(payload)
    payload[:user_id] = analytics_user.uuid
    payload[:user_agent] = request.user_agent
    payload[:ip] = request.remote_ip
    payload[:host] = request.host
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
    @user_event_creator ||= UserEventCreator.new(request, current_user)
  end
  delegate :create_user_event, :create_user_event_with_disavowal, to: :user_event_creator

  def decorated_session
    @_decorated_session ||= DecoratedSession.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    ).call
  end

  def default_url_options
    { locale: locale_url_param, host: Figaro.env.domain_name }
  end

  def sign_out(*args)
    request.cookie_jar.delete('ahoy_visit')
    super
  end

  private

  # These attributes show up in New Relic traces for all requests.
  # https://docs.newrelic.com/docs/agents/manage-apm-agents/agent-data/collect-custom-attributes
  def add_new_relic_trace_attributes
    ::NewRelic::Agent.add_custom_attributes(
      amzn_trace_id: request.headers['X-Amzn-Trace-Id'],
    )
  end

  def disable_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
  end

  def redirect_on_timeout
    return unless params[:timeout]

    unless current_user
      flash[:notice] = t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
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

  def after_sign_in_path_for(_user)
    add_piv_cac_setup_url || user_session.delete(:stored_location) ||
      sp_session_request_url_without_prompt_login || signed_in_url
  end

  def signed_in_url
    user_fully_authenticated? ? account_or_verify_profile_url : user_two_factor_authentication_url
  end

  def two_2fa_setup
    if MfaPolicy.new(current_user).sufficient_factors_enabled?
      after_multiple_2fa_sign_up
    elsif MfaPolicy.new(current_user).retire_personal_key?
      two_factor_options_path
    else
      two_factor_options_success_url
    end
  end

  def after_multiple_2fa_sign_up
    if needs_completions_screen?
      sign_up_completed_url
    elsif user_needs_to_reactivate_account?
      reactivate_account_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def user_needs_to_reactivate_account?
    return false if current_user.decorate.password_reset_profile.blank?
    sp_session[:ial2] == true
  end

  def ga_cookie_client_id
    return if ga_cookie.blank?
    ga_client_id = ga_cookie.match('GA1\.\d\.(\d+\.\d+)')
    return ga_client_id[1] if ga_client_id
  end

  def ga_cookie
    cookies[:_ga]
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
      two_factor_enabled? && is_fully_authenticated?
  end

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def confirm_two_factor_authenticated(id = nil)
    return redirect_to(new_user_session_url(request_id: id)) if !user_signed_in? && id.present?
    authenticate_user!(force: true)
    return if user_fully_authenticated? &&
              MfaPolicy.new(current_user).sufficient_factors_enabled?
    return prompt_to_set_up_2fa if user_fully_authenticated? || !two_factor_enabled?
    prompt_to_enter_otp
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  def prompt_to_set_up_2fa
    redirect_to two_factor_options_url
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_url
  end

  def two_factor_enabled?
    MfaPolicy.new(current_user).two_factor_enabled?
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def set_locale
    I18n.locale = LocaleChooser.new(params[:locale], request).locale
  end

  def increment_monthly_auth_count
    return unless current_user&.id
    issuer = sp_session[:issuer]
    return if issuer.blank? || !first_auth_of_session?(issuer)
    MonthlyAuthCount.increment(current_user.id, issuer)
  end

  def first_auth_of_session?(issuer)
    authenticated_to_sp_token = "auth-counted-#{issuer}"
    authenticated_to_sp = user_session[authenticated_to_sp_token]
    return if authenticated_to_sp
    user_session[authenticated_to_sp_token] = true
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
    Db::SpCost::AddSpCost.call(sp_session[:issuer].to_s, sp_session[:ial2] ? 2 : 1, token)
  end

  def mobile?
    client = DeviceDetector.new(request.user_agent)
    client.device_type != 'desktop'
  end
end
