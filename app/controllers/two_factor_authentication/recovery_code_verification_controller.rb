module TwoFactorAuthentication
  class RecoveryCodeVerificationController < DeviseController
    include ScopeAuthenticator
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_scope!

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
