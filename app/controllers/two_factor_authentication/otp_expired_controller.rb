module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    def show
      @otp_delivery_preference = current_user.otp_delivery_preference
    end
  end
end
