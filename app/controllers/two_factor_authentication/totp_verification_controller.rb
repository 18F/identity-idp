module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    skip_before_action :handle_two_factor_authentication
    before_action :confirm_totp_enabled

    def show
      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      result = TotpVerificationForm.new(current_user, params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h)

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
