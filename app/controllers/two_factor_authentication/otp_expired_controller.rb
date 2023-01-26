module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    before_action :confirm_two_factor_authenticated, unless: :user_signed_in?
    before_action :validate_otp_expiration

    def show
      @otp_delivery_preference = otp_delivery_preference
    end

    private

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end

  end
end
