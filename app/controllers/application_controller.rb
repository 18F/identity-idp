class ApplicationController < ActionController::Base
  include Pundit

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :render_401
  rescue_from ActionController::InvalidAuthenticityToken,
              with: :invalid_auth_token

  helper_method :user_fully_authenticated?, :generate_warning, :read_help_content

  prepend_before_action :session_expires_at

  def session_expires_at
    session[:session_expires_at] = Time.zone.now + Devise.timeout_in
  end

  def append_info_to_payload(payload)
    payload[:time] = Time.zone.now
    payload[:user_agent] = request.user_agent
    payload[:ip] = request.remote_ip
  end

  def analytics
    @analytics ||= Analytics.new(current_user, request_attributes, ahoy)
  end

  private

  def after_sign_in_path_for(resource)
    analytics.track_event('Authentication Successful')
    stored_location_for(resource) || session[:saml_request_url] || profile_path
  end

  def render_401
    render file: 'public/401.html', status: 401
  end

  def invalid_auth_token
    analytics.track_event('InvalidAuthenticityToken')
    sign_out
    flash[:error] = t('errors.invalid_authenticity_token')
    redirect_to root_url
  end

  def user_fully_authenticated?
    user_signed_in? && current_user.two_factor_enabled? && is_fully_authenticated?
  end

  def confirm_two_factor_authenticated
    authenticate_user!(force: true)

    user_decorator = UserDecorator.new(current_user)

    return if user_decorator.may_bypass_2fa?(session) || user_fully_authenticated?

    return prompt_to_set_up_2fa unless current_user.two_factor_enabled?

    prompt_to_enter_otp
  end

  def prompt_to_set_up_2fa
    redirect_to users_otp_url
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_url
  end

  def request_attributes
    {
      user_agent: request.user_agent,
      user_ip: request.remote_ip
    }
  end

  def ahoy
    @ahoy ||= Rails.env.test? ? NullAhoyTracker.new : Ahoy::Tracker.new(request: request)
  end
end
