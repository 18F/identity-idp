module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    before_action :redirect_unless_otp_expired_feature_on
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?

    def show
      @otp_delivery_preference = otp_delivery_preference
    end

    private

    def redirect_unless_otp_expired_feature_on
      return if IdentityConfig.store.session.allow_otp_countdown_expired_redirect
      redirect_to root_url
    end

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end
  end
end
