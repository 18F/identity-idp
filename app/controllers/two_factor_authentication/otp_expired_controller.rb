module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    before_action :validate_otp_expiration

    def show
      @otp_delivery_preference = otp_delivery_preference
    end

    private

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end

    def validate_otp_expiration
      redirect_to account_url if user_fully_authenticated?
    end
  end
end
