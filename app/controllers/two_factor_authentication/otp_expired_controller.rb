module TwoFactorAuthentication
  class OtpExpiredController < ApplicationController
    before_action :phone_method_selected

    def show
      @otp_delivery_preference = otp_delivery_preference
      @show_try_again_option = show_try_again_option?
    end

    private

    def otp_delivery_preference
      current_user.otp_delivery_preference
    end

    def show_try_again_option?
      !user_fully_authenticated?
    end
  end
end
