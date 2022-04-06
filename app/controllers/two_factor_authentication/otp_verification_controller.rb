module TwoFactorAuthentication
  class OtpVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include MfaSetupConcern

    before_action :check_sp_required_mfa_bypass
    before_action :confirm_multiple_factors_enabled
    before_action :confirm_voice_capability, only: [:show]

    def show
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_ENTER_OTP_VISIT, analytics_properties)

      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      result = OtpVerificationForm.new(current_user, sanitized_otp_code).submit
      post_analytics(result)
      if result.success?
        next_url = nil
        user_next_authentication_setup_path! if UserSessionContext.confirmation_context?(context)
        handle_valid_otp(next_url)
      else
        handle_invalid_otp
      end
    end

    private

    def confirm_multiple_factors_enabled
      return if UserSessionContext.confirmation_context?(context) || phone_enabled?

      if MfaPolicy.new(current_user).two_factor_enabled? &&
         !phone_enabled? && user_signed_in?
        return redirect_to user_two_factor_authentication_url
      end

      redirect_to phone_setup_url
    end

    def phone_enabled?
      TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?
    end

    def confirm_voice_capability
      return if two_factor_authentication_method == 'sms'

      phone_is_confirmed = UserSessionContext.authentication_context?(context)

      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: phone_is_confirmed)

      return if capabilities.supports_voice?

      flash[:error] = t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: capabilities.unsupported_location,
      )
      redirect_to login_two_factor_url(otp_delivery_preference: 'sms', reauthn: reauthn?)
    end

    def phone
      MfaContext.new(current_user).phone_configuration(user_session[:phone_id])&.phone ||
        user_session[:unconfirmed_phone]
    end

    def sanitized_otp_code
      form_params[:code].to_s.strip
    end

    def form_params
      params.permit(:code)
    end

    def post_analytics(result)
      properties = result.to_h.merge(analytics_properties)
      if context == 'confirmation'
        analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, properties)
      end

      analytics.track_mfa_submit_event(properties)
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: params[:otp_delivery_preference],
        confirmation_for_add_phone: confirmation_for_add_phone?,
        phone_configuration_id: user_session[:phone_id] ||
          current_user.default_phone_configuration&.id,
      }
    end
  end
end
