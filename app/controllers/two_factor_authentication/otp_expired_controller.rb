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

    def validate_otp_expiration
      redirect_to after_sign_in_path_for(current_user) if user_signed_in? && !otp_expired?
    end

    def otp_expired?
      return if current_user.direct_otp_sent_at.blank?
      (current_user.direct_otp_sent_at +
        TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_SECONDS).past?
    end
  end
end
