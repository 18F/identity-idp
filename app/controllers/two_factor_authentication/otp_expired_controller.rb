module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    include TwoFactorAuthenticatableMethods
    before_action :redirect_unless_otp_expired_redirect_enabled
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?

    def show
      @otp_delivery_preference = otp_delivery_preference
      @use_another_phone_path = use_another_phone_path
      @authentication_options_path = authentication_options_path
      analytics.otp_expired_visited(
        otp_sent_at: current_user.redis_direct_otp_sent_at,
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
      if new_account_mfa_registration?
        authentication_methods_setup_url
      elsif adding_phone_to_existing_account?
        account_url
      else
        login_two_factor_options_url
      end
    end

    def new_account_mfa_registration?
      user_session.key?(:mfa_selections)
    end

    def adding_phone_to_existing_account?
      unconfirmed_phone? && !new_account_mfa_registration?
    end

    def use_another_phone_path
      if adding_phone_to_existing_account?
        add_phone_path
      elsif unconfirmed_phone?
        phone_setup_path
      end
    end

    def unconfirmed_phone?
      user_session[:unconfirmed_phone].present? && UserSessionContext.confirmation_context?(context)
    end
  end
end
