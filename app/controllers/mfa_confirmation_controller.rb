class MfaConfirmationController < ApplicationController
  include MfaSetupConcern
  before_action :confirm_two_factor_authenticated

  def show
    @content = mfa_confirmation_presenter
    analytics.user_registration_suggest_another_mfa_notice_visited
  end

  def skip
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    analytics.user_registration_suggest_another_mfa_notice_skipped
    analytics.user_registration_mfa_setup_complete(
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
      success: true,
    )
    redirect_to after_skip_path
  end

  def new
    session[:password_attempts] ||= 0
  end

  def create
    valid_password = current_user.valid_password?(password)

    irs_attempts_api_tracker.logged_in_profile_change_reauthentication_submitted(
      success: valid_password,
    )
    if valid_password
      handle_valid_password
    else
      handle_invalid_password
    end
  end

  private

  def mfa_confirmation_presenter
    MfaConfirmationPresenter.new(
      show_skip_additional_mfa_link: show_skip_additional_mfa_link?,
    )
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
    irs_attempts_api_tracker.logged_in_profile_change_reauthentication_rate_limited
    sign_out
    redirect_to root_url, flash: { error: t('errors.max_password_attempts_reached') }
  end

  def mfa_context
    @mfa_context ||= MfaContext.new(current_user)
  end

  def after_skip_path
    if backup_code_confirmation_needed?
      confirm_backup_codes_path
    else
      after_mfa_setup_path
    end
  end

  def backup_code_confirmation_needed?
    !MfaPolicy.new(current_user).multiple_factors_enabled? && user_backup_codes_configured?
  end
end
