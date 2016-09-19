module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  included do
    prepend_before_action :authenticate_user!
    before_action :verify_user_is_not_second_factor_locked
    before_action :handle_two_factor_authentication
    before_action :check_already_authenticated
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :create
  end

  private

  def verify_user_is_not_second_factor_locked
    handle_second_factor_locked_user if user_decorator.blocked_from_entering_2fa_code?
  end

  def handle_second_factor_locked_user
    analytics.track_event('User reached max 2FA attempts')

    render 'two_factor_authentication/shared/max_login_attempts_reached'

    sign_out
  end

  def check_already_authenticated
    redirect_to profile_path if user_fully_authenticated?
  end

  def reset_attempt_count_if_user_no_longer_locked_out
    return unless user_decorator.no_longer_blocked_from_entering_2fa_code?

    current_user.update(second_factor_attempts_count: 0, second_factor_locked_at: nil)
  end

  def handle_valid_otp
    user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false

    bypass_sign_in current_user
    flash[:notice] = t('devise.two_factor_authentication.success')

    analytics.track_event('User 2FA successful')

    current_user.update(second_factor_attempts_count: 0)

    redirect_to after_sign_in_path_for(current_user)
  end

  def handle_invalid_otp
    analytics.track_event('User entered invalid 2FA code')

    update_invalid_user if current_user.two_factor_enabled?

    flash[:error] = t('devise.two_factor_authentication.attempt_failed')

    if user_decorator.blocked_from_entering_2fa_code?
      handle_second_factor_locked_user
    else
      render :show
    end
  end

  def update_invalid_user
    current_user.second_factor_attempts_count += 1
    # set time lock if max attempts reached
    current_user.second_factor_locked_at = Time.zone.now if current_user.max_login_attempts?
    current_user.save
  end

  def user_decorator
    @user_decorator ||= current_user.decorate
  end
end
