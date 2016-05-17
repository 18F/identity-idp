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

  private

  def link_identity_from_session_data(resource = current_user, authenticated = true)
    linker = IdentityLinker.new(resource, authenticated, sp_data)

    linker.set_active_identity
    linker.update_user_and_identity_if_ial_token

    session.delete(:sp_data)
  end

  def sp_data
    session.fetch(:sp_data, {})
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_index_path
  end

  def render_401
    render file: 'public/401.html', status: 401
  end

  def invalid_auth_token
    logger.info 'Rescuing InvalidAuthenticityToken'
    flash[:error] = I18n.t('upaya.errors.invalid_authenticity_token')
    sign_out current_user
    redirect_to root_url
  end

  def user_fully_authenticated?
    user_signed_in? && current_user.two_factor_enabled? && is_fully_authenticated?
  end

  def confirm_two_factor_authenticated
    authenticate_user!

    user_decorator = UserDecorator.new(current_user)

    return if user_decorator.may_bypass_2fa?(session) || user_fully_authenticated?

    return prompt_to_set_up_2fa unless current_user.two_factor_enabled?

    prompt_to_enter_otp
  end

  def prompt_to_set_up_2fa
    flash[:notice] = t('devise.two_factor_authentication.otp_setup')
    redirect_to users_otp_url
  end

  def prompt_to_enter_otp
    redirect_to user_two_factor_authentication_url
  end
end
