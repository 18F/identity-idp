module TwoFactorAuthentication
  class OtpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    skip_before_action :handle_two_factor_authentication

    def show
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_ENTER_OTP_VISIT, analytics_properties)
      @presenter = presenter_for(delivery_method)
    end

    def create
      result = OtpVerificationForm.new(current_user, form_params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.merge(analytics_properties))

      if result[:success]
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
        method: params[:delivery_method],
        confirmation_for_phone_change: confirmation_for_phone_change?
      }
    end

    def confirmation_for_phone_change?
      context == 'confirmation' && current_user.phone.present?
    end
  end
end
