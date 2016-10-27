module TwoFactorAuthentication
  class TotpVerificationController < DeviseController
    include TwoFactorAuthenticatable

    def show
    end

    def create
      result = TotpVerificationForm.new(current_user, params[:code].strip).submit

      analytics.track_event(Analytics::AUTHENTICATION_TOTP, result)

      if result[:success?]
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end
  end
end
