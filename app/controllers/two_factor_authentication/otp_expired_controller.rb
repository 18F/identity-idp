module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    def show
      @otp_delivery_preference = otp_delivery_preference
      @show_try_again_option = show_try_again_option?
    end

    private

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end

    def show_try_again_option?
      !two_factor_enabled?
    end
  end
end
