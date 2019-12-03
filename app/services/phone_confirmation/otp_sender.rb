module PhoneConfirmation
  class OtpSender
    attr_reader :user, :phone_confirmation_session, :context, :telephony_error

    def initialize(user:, phone_confirmation_session:, context: :confirmation)
      @user = user
      @phone_confirmation_session = phone_confirmation_session
      @context = context
    end

    def send_otp
      return handle_too_many_otp_sends if exceeded_otp_send_limit?
      otp_rate_limiter.increment
      return handle_too_many_otp_sends if exceeded_otp_send_limit?

      Telephony.send(otp_method_name, otp_method_params)
      FormResponse.new(success: true, errors: {})
    rescue Telephony::TelephonyError => telephony_error
      handle_telephony_error(telephony_error)
    end

    def telephony_error?
      @telephony_error.present?
    end

    def rate_limited?
      @exceeded_otp_send_limit
    end

    private

    def otp_method_name
      if context == :authentication
        :send_authentication_otp
      elsif context == :confirmation
        :send_confirmation_otp
      end
    end

    def otp_method_params
      {
        to: phone_confirmation_session.phone,
        otp: phone_confirmation_session.code,
        expiration: Devise.direct_otp_valid_for.to_i / 60,
        channel: phone_confirmation_session.delivery_method,
      }
    end

    def user_no_longer_locked_out?
      UserDecorator.new(user).no_longer_locked_out?
    end

    def exceeded_otp_send_limit?
      @exceeded_otp_send_limit = otp_rate_limiter.exceeded_otp_send_limit?
    end

    def handle_too_many_otp_sends
      otp_rate_limiter.lock_out_user
      FormResponse.new(
        success: false,
        errors: { base: ['To many OTP requests'] },
      )
    end

    def otp_rate_limiter
      @otp_rate_limiter ||= OtpRateLimiter.new(phone: phone_confirmation_session.phone, user: user)
    end

    def handle_telephony_error(error)
      @telephony_error = error
      telephony_error_form_response
    end

    def telephony_error_form_response
      FormResponse.new(
        success: false,
        errors: { base: [telephony_error.friendly_message] },
        extra: {
          telephony_error_class: telephony_error.class.to_s,
          telephony_error_message: telephony_error.message,
        },
      )
    end
  end
end
