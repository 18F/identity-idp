module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    include TwoFactorAuthenticatableMethods
    before_action :redirect_unless_otp_expired_redirect_enabled
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?

    def show
      @otp_delivery_preference = otp_delivery_preference
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
  end
end
