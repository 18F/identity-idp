module Idv
  class ResendOtpController < ApplicationController
    include IdvSession
    include TwoFactorAuthenticatable

    # Skip TwoFactorAuthenticatable before action that depends on MFA contexts
    # to redirect to account url for signed in users. This controller does not
    # use or maintain MFA contexts
    skip_before_action :check_already_authenticated

    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_phone_confirmation_needed
    before_action :handle_locked_out_user
    before_action :confirm_otp_delivery_preference_selected

    def create
      result = send_phone_confirmation_otp_service.call
      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION_OTP_SENT, result.to_h)
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

    def handle_locked_out_user
      reset_attempt_count_if_user_no_longer_locked_out
      return unless decorated_user.locked_out?
      handle_second_factor_locked_user 'generic'
      false
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
