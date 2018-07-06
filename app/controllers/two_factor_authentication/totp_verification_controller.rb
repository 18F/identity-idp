module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_totp_enabled

    def show
      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      result = verification_form.submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h)

      if result.success?
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end

    private

    def verification_form
      TwoFactorAuthentication::TotpVerifyForm.new(
        user: current_user,
        configuration_manager: configuration_manager,
        code: params[:code].strip
      )
    end

    def confirm_totp_enabled
      return if configuration_manager.enabled?

      redirect_to user_two_factor_authentication_url
    end
  end
end
