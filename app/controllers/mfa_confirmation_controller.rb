class MfaConfirmationController < ApplicationController
  include MfaSetupConcern
  before_action :confirm_two_factor_authenticated

  def show
    @content = MfaConfirmationPresenter.new(current_user)
    @next_path = next_path
  end

  def skip
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    redirect_to after_mfa_setup_path
  end

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

  def enforce_second_mfa?
    IdentityConfig.store.select_multiple_mfa_options &&
      MfaContext.new(current_user).enabled_non_restricted_mfa_methods_count < 1
  end

  def next_path
    return second_mfa_setup_non_restricted_path if enforce_second_mfa?
    second_mfa_setup_path
  end

  def password
    params.require(:user)[:password]
  end

  def handle_valid_password
    if current_user.auth_app_configurations.any?
      redirect_to login_two_factor_authenticator_url(reauthn: true)
    else
      redirect_to user_two_factor_authentication_url(reauthn: true)
    end
    session[:password_attempts] = 0
    user_session[:current_password_required] = false
  end

  def handle_invalid_password
    session[:password_attempts] = session[:password_attempts].to_i + 1

    if session[:password_attempts] < IdentityConfig.store.password_max_attempts
      flash[:error] = t('errors.confirm_password_incorrect')
      redirect_to user_password_confirm_url
    else
      handle_max_password_attempts_reached
    end
  end

  def handle_max_password_attempts_reached
    analytics.password_max_attempts
    sign_out
    redirect_to root_url, flash: { error: t('errors.max_password_attempts_reached') }
  end
end
