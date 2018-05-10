module TwoFactorAuthentication
  class OtpVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_two_factor_enabled
    before_action :confirm_voice_capability, only: [:show]

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

    def confirm_voice_capability
      return if two_factor_authentication_method == 'sms'

      phone = current_user&.phone || user_session[:unconfirmed_phone]
      capabilities = PhoneNumberCapabilities.new(phone)

      return unless capabilities.sms_only?

      flash[:error] = t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: capabilities.unsupported_location
      )
      redirect_to login_two_factor_url(otp_delivery_preference: 'sms', reauthn: reauthn?)
    end

    def form_params
      params.permit(:code)
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: params[:otp_delivery_preference],
        confirmation_for_phone_change: confirmation_for_phone_change?,
      }
    end
  end
end
