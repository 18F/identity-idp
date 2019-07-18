class PasswordCaptureController < ApplicationController
  include Ial2ProfileConcern
  include TwoFactorAuthenticatableMethods
  include SecureHeadersConcern

  before_action :confirm_two_factor_authenticated
  before_action :apply_secure_headers_override

  def new
    session[:password_attempts] ||= 0
  end

  def create
    if current_user.valid_password?(password)
      handle_valid_password
    else
      handle_invalid_password
    end
  end

  private

  def password
    params.require(:user)[:password]
  end

  def handle_valid_password
    cache_active_profile(password)
    session[:password_attempts] = 0
    user_session[:current_password_required] = false
    redirect_to after_otp_verification_confirmation_url
  end

  # :reek:DuplicateMethodCall
  def handle_invalid_password
    session[:password_attempts] += 1

    if session[:password_attempts] < Figaro.env.password_max_attempts.to_i
      flash[:error] = t('errors.confirm_password_incorrect')
      redirect_to capture_password_url
    else
      handle_max_password_attempts_reached
    end
  end

  def handle_max_password_attempts_reached
    analytics.track_event(Analytics::PASSWORD_MAX_ATTEMPTS)
    sign_out
    redirect_to root_url, alert: t('errors.max_password_attempts_reached')
  end
end
