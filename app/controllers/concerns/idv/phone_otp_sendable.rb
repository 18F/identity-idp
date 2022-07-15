module Idv
  module PhoneOtpSendable
    extend ActiveSupport::Concern

    included do
      before_action :confirm_two_factor_authenticated
      before_action :handle_locked_out_user
    end

    def send_phone_confirmation_otp
      send_phone_confirmation_otp_service.call
    end

    def send_phone_confirmation_otp_rate_limited?
      send_phone_confirmation_otp_service.user_locked_out?
    end

    def invalid_phone_number(telephony_error)
      capture_analytics_for_telephony_error(telephony_error)
      flash[:error] = telephony_error.friendly_message
      redirect_to idv_phone_url
    end

    private

    def send_phone_confirmation_otp_service
      @send_phone_confirmation_otp_service ||= Idv::SendPhoneConfirmationOtp.new(
        user: current_user,
        idv_session: idv_session,
      )
    end

    def capture_analytics_for_telephony_error(telephony_error)
      analytics.otp_phone_validation_failed(
        error: telephony_error.class.to_s,
        message: telephony_error.message,
        context: 'idv',
        country: Phonelib.parse(send_phone_confirmation_otp_service.phone).country,
      )
    end
  end
end
