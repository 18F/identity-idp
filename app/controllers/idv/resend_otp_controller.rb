module Idv
  class ResendOtpController < ApplicationController
    include IdvSession
    include PhoneOtpRateLimitable
    include PhoneOtpSendable

    # confirm_two_factor_authenticated before action is in PhoneOtpRateLimitable
    before_action :confirm_user_phone_confirmation_needed
    before_action :confirm_user_phone_confirmation_session_started

    def create
      result = send_phone_confirmation_otp
      analytics.idv_phone_confirmation_otp_resent(**result.to_h)
      if result.success?
        redirect_to idv_otp_verification_url
      else
        handle_send_phone_confirmation_otp_failure(result)
      end
    end

    private

    def handle_send_phone_confirmation_otp_failure(result)
      if send_phone_confirmation_otp_rate_limited?
        handle_too_many_otp_sends
      else
        invalid_phone_number(result.extra[:telephony_response].error)
      end
    end

    def confirm_user_phone_confirmation_needed
      return unless idv_session.user_phone_confirmation
      redirect_to idv_review_url
    end

    def confirm_user_phone_confirmation_session_started
      return if idv_session.user_phone_confirmation_session.present?

      redirect_to idv_phone_url
    end
  end
end
