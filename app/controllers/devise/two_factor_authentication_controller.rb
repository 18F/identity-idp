require 'feature_management'

module Devise
  class TwoFactorAuthenticationController < DeviseController
    include ScopeAuthenticator

    prepend_before_action :authenticate_scope!
    before_action :verify_user_is_not_second_factor_locked
    before_action :handle_two_factor_authentication
    before_action :check_already_authenticated

    def new
      analytics.track_event('User requested a new OTP code')

      current_user.send_new_otp
      flash[:notice] = t('devise.two_factor_authentication.user.new_otp_sent')
      redirect_to user_two_factor_authentication_path(method: 'sms')
    end

    def show
      analytics.track_pageview

      if use_totp?
        show_totp_prompt
      else
        show_direct_otp_prompt
      end
    end

    def update
      reset_attempt_count_if_user_no_longer_locked_out

      if resource.authenticate_otp(params[:code].strip)
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end

    private

    def check_already_authenticated
      redirect_to profile_path if user_fully_authenticated?
    end

    def use_totp?
      # Present the TOTP entry screen to users who are TOTP enabled, unless the user explictly
      # selects SMS
      current_user.totp_enabled? && params[:method] != 'sms'
    end

    def verify_user_is_not_second_factor_locked
      handle_second_factor_locked_resource if user_decorator.blocked_from_entering_2fa_code?
    end

    def reset_attempt_count_if_user_no_longer_locked_out
      return unless user_decorator.no_longer_blocked_from_entering_2fa_code?

      resource.update(second_factor_attempts_count: 0, second_factor_locked_at: nil)
    end

    def handle_valid_otp
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false

      bypass_sign_in resource
      flash[:notice] = t('devise.two_factor_authentication.success')

      update_metrics

      resource.update(second_factor_attempts_count: 0)

      redirect_valid_resource
    end

    def update_metrics
      analytics.track_event('User 2FA successful')
    end

    def redirect_valid_resource
      redirect_to after_sign_in_path_for(resource)
    end

    def show_direct_otp_prompt
      @code_value = current_user.direct_otp if FeatureManagement.prefill_otp_codes?

      @phone_number = user_decorator.masked_two_factor_phone_number
      render :show
    end

    def show_totp_prompt
      render :show_totp
    end

    def handle_invalid_otp
      analytics.track_event('User entered invalid 2FA code')

      update_invalid_resource if resource.two_factor_enabled?

      flash.now[:error] = t('devise.two_factor_authentication.attempt_failed')

      if user_decorator.blocked_from_entering_2fa_code?
        handle_second_factor_locked_resource
      else
        show
      end
    end

    def update_invalid_resource
      resource.second_factor_attempts_count += 1
      # set time lock if max attempts reached
      resource.second_factor_locked_at = Time.zone.now if resource.max_login_attempts?
      resource.save
    end

    def handle_second_factor_locked_resource
      analytics.track_event('User reached max 2FA attempts')

      render :max_login_attempts_reached

      sign_out
    end

    def user_decorator
      @user_decorator ||= UserDecorator.new(current_user)
    end
  end
end
