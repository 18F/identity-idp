module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    def show
      @otp_delivery_preference = otp_delivery_preference
    end

    private

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end
  end
end
