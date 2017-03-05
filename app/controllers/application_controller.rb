class ApplicationController < ActionController::Base # rubocop:disable Metrics/ClassLength
  include BrandedExperience
  include UserSessionContext

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken,
              with: :invalid_auth_token

  helper_method :decorated_user, :reauthn?, :user_fully_authenticated?

  prepend_before_action :session_expires_at
  before_action :set_locale
  before_action :disable_caching

  layout 'card'

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
    @analytics ||= Analytics.new(analytics_user, request)
  end

  def analytics_user
    current_user || AnonymousUser.new
  end

  def create_user_event(event_type, user = current_user)
    Event.create(user_id: user.id, event_type: event_type)
  end

  private

  def disable_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
  end

  def redirect_on_timeout
    params = request.query_parameters
    return unless params[:timeout]

    params[:issuer].present? ? redirect_with_sp : redirect_without_sp
  end

  def sp_metadata
    ServiceProvider.from_issuer(request.query_parameters[:issuer]).metadata
  end

  def sp_name
    sp_metadata[:friendly_name] || sp_metadata[:agency]
  end

  def redirect_with_sp # rubocop:disable Metrics/AbcSize
    flash[:timeout] = t(
      'notices.session_cleared_with_sp',
      link: view_context.link_to(sp_name, sp_metadata[:return_to_sp_url]),
      minutes: Figaro.env.session_timeout_in_minutes,
      sp: sp_name
    )
    redirect_to url_for(request.query_parameters.except(:timeout))
  end

  def redirect_without_sp
    flash[:timeout] = t('notices.session_cleared', minutes: Figaro.env.session_timeout_in_minutes)
    redirect_to url_for(request.query_parameters.except(:issuer, :timeout))
  end

  def decorated_user
    @_decorated_user ||= current_user.decorate
  end

  def after_sign_in_path_for(user)
    stored_location_for(user) || sp_session[:request_url] || profile_path
  end

  def render_401
    render file: 'public/401.html', status: 401
  end

  def reauthn_param
    params[:reauthn]
  end

  def reauthn?
    reauthn = reauthn_param
    reauthn.present? && reauthn == 'true'
  end

  def invalid_auth_token
    analytics.track_event(Analytics::INVALID_AUTHENTICITY_TOKEN)
    sign_out
    flash[:error] = t('errors.invalid_authenticity_token')
    redirect_to root_url
  end

  def user_fully_authenticated?
    !reauthn? && user_signed_in? && current_user.two_factor_enabled? && is_fully_authenticated?
  end

  def confirm_two_factor_authenticated
    authenticate_user!(force: true)

    return if user_fully_authenticated?

    return prompt_to_set_up_2fa unless current_user.two_factor_enabled?

    prompt_to_enter_otp
  end

  def prompt_to_set_up_2fa
    redirect_to phone_setup_path
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_path
  end

  def skip_session_expiration
    @skip_session_expiration = true
  end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def sp_session
    session.fetch(:sp, {})
  end
end
