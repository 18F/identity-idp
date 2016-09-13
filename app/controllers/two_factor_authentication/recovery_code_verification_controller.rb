module TwoFactorAuthentication
  class RecoveryCodeVerificationController < DeviseController
    include ScopeAuthenticator
    include TwoFactorAuthenticatable

    prepend_before_action :authenticate_scope!

    def show
    end

    def create
      result = RecoveryCodeForm.new(current_user, params[:code]).submit

      analytics.track_event(:recovery_code_authentication, result)

      if result[:success?]
        handle_valid_otp
      else
        handle_invalid_otp(type: 'recovery_code')
      end
    end
  end
end
