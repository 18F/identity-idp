module TwoFactorAuthentication
  class OtpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled

    def show
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_ENTER_OTP_VISIT, analytics_properties)

      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      result = OtpVerificationForm.new(current_user, form_params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h.merge(analytics_properties))

      if result.success?
        handle_valid_otp
      else
        handle_invalid_otp
      end
    end

    private

    def confirm_two_factor_enabled
      return if confirmation_context? || current_user.two_factor_enabled?

      redirect_to phone_setup_url
    end

    def form_params
      params.permit(:code)
    end

    def analytics_properties
      {
        context: context,
        method: params[:otp_delivery_preference],
        confirmation_for_phone_change: confirmation_for_phone_change?,
      }
    end
  end
end
