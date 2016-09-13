module TwoFactorAuthentication
  class TotpVerificationController < DeviseController
    include TwoFactorAuthenticatable

    def show
    end

    def create
      if current_user.authenticate_totp(params[:code].strip)
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end
  end
end
