module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_totp_enabled

    def show
      analytics.multi_factor_auth_enter_totp_visit(context: context)

      @presenter = presenter_for_two_factor_authentication_method
      return unless FeatureManagement.prefill_otp_codes?
      @code = ROTP::TOTP.new(
        current_user.auth_app_configurations.first.otp_secret_key,
        interval: IdentityConfig.store.totp_code_interval,
      ).now
    end

    def create
      result = TotpVerificationForm.new(current_user, normalized_code_param).submit

      analytics.track_mfa_submit_event(result.to_h)
      irs_attempts_api_tracker.mfa_login_totp(success: result.success?)

      if result.success?
        handle_valid_otp
      else
        handle_invalid_otp(context: context, type: 'totp', code: normalized_code_param)
      end
    end

    private

    def normalized_code_param
      params.require(:code).strip
    end

    def confirm_totp_enabled
      return if current_user.auth_app_configurations.any?

      redirect_to user_two_factor_authentication_url
    end
  end
end
