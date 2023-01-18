module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    def show
      @otp_delivery_preference = current_user.otp_delivery_preference
      @sp_name = decorated_session.sp_name
    end
  end
end
