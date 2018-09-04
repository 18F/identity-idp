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

    def invalid_phone_number(exception)
      capture_analytics_for_twilio_exception(exception)
      twilio_errors = TwilioErrors::REST_ERRORS.merge(TwilioErrors::VERIFY_ERRORS)
      flash[:error] = twilio_errors.fetch(exception.code, t('errors.messages.otp_failed'))
      redirect_to idv_phone_url
    end

    private

    def send_phone_confirmation_otp_service
      @send_phone_confirmation_otp_service ||= Idv::SendPhoneConfirmationOtp.new(
        user: current_user,
        idv_session: idv_session,
        locale: user_locale
      )
    end

    def user_locale
      available_locales = PhoneVerification::AVAILABLE_LOCALES
      http_accept_language.language_region_compatible_from(available_locales)
    end

    # rubocop:disable Metrics/MethodLength
    # :reek:FeatureEnvy
    def capture_analytics_for_twilio_exception(exception)
      attributes = {
        error: exception.message,
        code: exception.code,
        context: 'idv',
        country: Phonelib.parse(send_phone_confirmation_otp_service.phone).country,
      }
      if exception.is_a?(PhoneVerification::VerifyError)
        attributes[:status] = exception.status
        attributes[:response] = exception.response
      end
      analytics.track_event(Analytics::TWILIO_PHONE_VALIDATION_FAILED, attributes)
    end
    # rubocop:enable Metrics/MethodLength
  end
end
