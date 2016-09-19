module TwoFactorAuthentication
  class OtpVerificationController < DeviseController
    include TwoFactorAuthenticatable

    def show
      @phone_number = user_decorator.masked_two_factor_phone_number
      @code_value = current_user.direct_otp if FeatureManagement.prefill_otp_codes?
      @delivery_method = params[:delivery_method]
    end

    def create
      if current_user.authenticate_direct_otp(params[:code].strip)
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end
  end
end
