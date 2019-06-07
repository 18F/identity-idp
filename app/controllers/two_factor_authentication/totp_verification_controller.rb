module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_totp_enabled

    def show
      @presenter = presenter_for_two_factor_authentication_method
      return unless FeatureManagement.prefill_otp_codes?
      @code = ROTP::TOTP.new(current_user.otp_secret_key).now
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_ENTER_TOTP_VISIT)
    end

    def create
      result = TotpVerificationForm.new(current_user, params[:code].strip).submit

      analytics.track_mfa_submit_event(result.to_h, ga_cookie_client_id)

      if result.success?
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end

    private

    def confirm_totp_enabled
      return if current_user.totp_enabled?

      redirect_to user_two_factor_authentication_url
    end
  end
end
