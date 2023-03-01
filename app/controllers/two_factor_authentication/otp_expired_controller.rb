module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    include TwoFactorAuthenticatableMethods
    before_action :redirect_unless_otp_expired_redirect_enabled
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?

    def show
      @otp_delivery_preference = otp_delivery_preference
      @use_another_phone_number = use_another_phone_number
      @next_path = set_choose_another_method_path
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

    def use_another_phone_number
      mfa_context.enabled_mfa_methods_count < 1
    end

    def set_choose_another_method_path
      if mfa_context.enabled_mfa_methods_count < 1
        @next_path = authentication_methods_setup_url
      else
        @next_path = login_two_factor_options_url
      end
    end
  end
end
