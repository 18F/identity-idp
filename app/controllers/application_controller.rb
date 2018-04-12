class ApplicationController < ActionController::Base
  include UserSessionContext
  include VerifyProfileConcern
  include LocaleHelper

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
    @analytics ||= Analytics.new(user: analytics_user, request: request, sp: current_sp&.issuer)
  end

  def analytics_user
    warden.user || AnonymousUser.new
  end

  def create_user_event(event_type, user = current_user)
    Event.create(user_id: user.id, event_type: event_type)
  end

  def decorated_session
    @_decorated_session ||= DecoratedSession.new(
      sp: current_sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request
    ).call
  end

  def default_url_options
    { locale: locale_url_param, host: Figaro.env.domain_name }
  end

  def sign_out
    request.cookie_jar.delete('ahoy_visit')
    super
  end

  private

  # These attributes show up in New Relic traces for all requests.
  # https://docs.newrelic.com/docs/agents/manage-apm-agents/agent-data/collect-custom-attributes
  def add_new_relic_trace_attributes
    ::NewRelic::Agent.add_custom_attributes(
      amzn_trace_id: request.headers['X-Amzn-Trace-Id']
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
    redirect_to url_for(permitted_timeout_params)
  end

  def permitted_timeout_params
    params.permit(:request_id)
  end

  def current_sp
    @current_sp ||= sp_from_sp_session || sp_from_request_id
  end

  def sp_from_sp_session
    sp = ServiceProvider.from_issuer(sp_session[:issuer])
    sp if sp.is_a? ServiceProvider
  end

  def sp_from_request_id
    sp = ServiceProvider.from_issuer(service_provider_request.issuer)
    sp if sp.is_a? ServiceProvider
  end

  def service_provider_request
    @service_provider_request ||= ServiceProviderRequest.from_uuid(params[:request_id])
  end

  def after_sign_in_path_for(_user)
    user_session[:stored_location] || sp_session[:request_url] || signed_in_url
  end

  def signed_in_url
    user_fully_authenticated? ? account_or_verify_profile_url : user_two_factor_authentication_url
  end

  def reauthn_param
    params[:reauthn]
  end

  def invalid_auth_token(_exception)
    controller_info = "#{controller_path}##{action_name}"
    analytics.track_event(
      Analytics::INVALID_AUTHENTICITY_TOKEN,
      controller: controller_info,
      user_signed_in: user_signed_in?
    )
    flash[:error] = t('errors.invalid_authenticity_token')
    redirect_back fallback_location: new_user_session_url
  end

  def user_fully_authenticated?
    !reauthn? && user_signed_in? && current_user.two_factor_enabled? && is_fully_authenticated?
  end

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  def confirm_two_factor_authenticated
    authenticate_user!(force: true)

    return if user_fully_authenticated?

    return prompt_to_set_up_2fa unless current_user.two_factor_enabled?

    prompt_to_enter_otp
  end

  def prompt_to_set_up_2fa
    redirect_to two_factor_options_url
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_url
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def set_locale
    I18n.locale = LocaleChooser.new(params[:locale], request).locale
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def render_not_found
    render template: 'pages/page_not_found', layout: false, status: 404, formats: :html
  end

  def render_timeout(exception)
    analytics.track_event(Analytics::RESPONSE_TIMED_OUT, analytics_exception_info(exception))
    render template: 'pages/page_took_too_long', layout: false, status: 503, formats: :html
  end

  def analytics_exception_info(exception)
    {
      backtrace: Rails.backtrace_cleaner.send(:filter, exception.backtrace),
      exception_message: exception.to_s,
      exception_class: exception.class.name,
    }
  end
end
