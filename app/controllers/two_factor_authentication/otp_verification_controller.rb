module TwoFactorAuthentication
  class OtpVerificationController < DeviseController
    include TwoFactorAuthenticatable

    def show
      assign_variables_for_otp_verification_show_view
      analytics.track_event(Analytics::USER_REGISTRATION_ENTER_PASSCODE_VISIT)
    end

    def create
      result = OtpVerificationForm.new(current_user, form_params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.merge(analytics_properties))

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

    def analytics_properties
      {
        context: context,
        method: params[:delivery_method]
      }
    end
  end
end
