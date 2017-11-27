class MfaConfirmationController < ApplicationController
  before_action :confirm_two_factor_authenticated

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
    if current_user.totp_enabled?
      redirect_to login_two_factor_authenticator_url(reauthn: true)
    else
      redirect_to user_two_factor_authentication_url(reauthn: true)
    end
    session[:password_attempts] = 0
    user_session[:current_password_required] = false
  end

  def handle_invalid_password
    session[:password_attempts] += 1

    if session[:password_attempts] < Figaro.env.password_max_attempts.to_i
      flash[:error] = t('errors.confirm_password_incorrect')
      redirect_to user_password_confirm_url
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
