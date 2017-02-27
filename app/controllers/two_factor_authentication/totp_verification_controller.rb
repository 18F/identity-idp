module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    skip_before_action :handle_two_factor_authentication

    helper_method :confirmation_for_phone_change?

    def show
      @presenter = presenter_for(delivery_method)
    end

    def create
      result = TotpVerificationForm.new(current_user, params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.merge(method: 'totp'))

      if result[:success]
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end
  end
end
