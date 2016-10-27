module TwoFactorAuthentication
  class OtpVerificationController < DeviseController
    include TwoFactorAuthenticatable

    def show
      assign_variables_for_otp_verification_show_view
    end

    def create
      result = OtpVerificationForm.new(current_user, form_params[:code].strip).submit

      analytics.track_event(Analytics::OTP_RESULT, result.merge(context: context))

      if result[:success?]
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end

    private

    def form_params
      params.permit(:code)
    end
  end
end
