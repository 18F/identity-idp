module TwoFactorAuthentication
  class RecoveryCodeVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_user
    skip_before_action :handle_two_factor_authentication

    def create
      result = RecoveryCodeForm.new(current_user, params[:code]).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.merge(method: 'recovery code'))

      if result[:success]
        handle_valid_otp
      else
        handle_invalid_otp(type: 'recovery_code')
      end
    end
  end
end
