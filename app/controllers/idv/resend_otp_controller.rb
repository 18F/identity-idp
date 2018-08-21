module Idv
  class ResendOtpController < ApplicationController
    include IdvSession
    include PhoneOtpRateLimitable

    # confirm_two_factor_authenticated before action is in PhoneOtpRateLimitable
    before_action :confirm_user_phone_confirmation_needed
    before_action :confirm_otp_delivery_preference_selected

    def create
      result = send_phone_confirmation_otp_service.call
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_RESENT, result.to_h)
      if send_phone_confirmation_otp_service.user_locked_out?
        handle_too_many_otp_sends
      else
        redirect_to idv_otp_verification_url
      end
    end

    private

    def confirm_user_phone_confirmation_needed
      return unless idv_session.user_phone_confirmation
      redirect_to idv_review_url
    end

    def confirm_otp_delivery_preference_selected
      return if idv_session.params[:phone].present? &&
                idv_session.phone_confirmation_otp_delivery_method.present?

      redirect_to idv_otp_delivery_method_url
    end

    def send_phone_confirmation_otp_service
      @send_phone_confirmation_otp_form ||= SendPhoneConfirmationOtp.new(
        user: current_user,
        idv_session: idv_session,
        locale: user_locale
      )
    end

    def user_locale
      available_locales = PhoneVerification::AVAILABLE_LOCALES
      http_accept_language.language_region_compatible_from(available_locales)
    end
  end
end
