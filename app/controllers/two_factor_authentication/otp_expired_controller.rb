module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    include TwoFactorAuthenticatableMethods
    before_action :redirect_unless_otp_expired_redirect_enabled
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?

    def show
      @otp_delivery_preference = otp_delivery_preference
      @show_use_another_phone_option = show_use_another_phone_option?
      @authentication_options_path = authentication_options_path
      analytics.otp_expired_visited(
        otp_sent_at: current_user.direct_otp_sent_at,
        otp_expiration: otp_expiration,
      )
    end

    private

    def redirect_unless_otp_expired_redirect_enabled
      return if FeatureManagement.otp_expired_redirect_enabled?
      redirect_to root_url
    end

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end

    def authentication_options_path
      if user_session.key?(:mfa_selections)
        authentication_methods_setup_url
      elsif adding_phone?
        account_url
      else
        login_two_factor_options_url
      end
    end

    def adding_phone?
      show_use_another_phone_option? && !user_session.key?(:mfa_selections)
    end

    def show_use_another_phone_option?
      user_session[:unconfirmed_phone].present? && UserSessionContext.confirmation_context?(context)
    end
  end
end
