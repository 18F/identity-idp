class ApplicationController < ActionController::Base
  include BrandedExperience

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken,
              with: :invalid_auth_token

  helper_method :decorated_user, :reauthn?, :user_fully_authenticated?

  prepend_before_action :session_expires_at
  before_action :set_locale

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

  def redirect_on_timeout
    request_params = request.query_parameters
    return unless request_params[:timeout]
    flash[:timeout] = t('notices.session_cleared')
    redirect_to url_for(request_params.except(:timeout))
  end

  def decorated_user
    @_decorated_user ||= current_user.decorate
  end

  def after_sign_in_path_for(user)
    stored_location_for(user) || session[:saml_request_url] || profile_path
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

    return if decorated_user.may_bypass_2fa?(session) || user_fully_authenticated?

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
end
