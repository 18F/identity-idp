module Idv
  class SendPhoneConfirmationOtp
    attr_reader :telephony_response

    def initialize(user:, idv_session:)
      @user = user
      @idv_session = idv_session
    end

    def call
      otp_rate_limiter.reset_count_and_otp_last_sent_at if user.decorate.no_longer_locked_out?

      return too_many_otp_sends_response if rate_limit_exceeded?
      otp_rate_limiter.increment
      return too_many_otp_sends_response if rate_limit_exceeded?

      send_otp
    end

    def user_locked_out?
      @user_locked_out
    end

    private

    attr_reader :user, :idv_session

    delegate :user_phone_confirmation_session, to: :idv_session
    delegate :phone, :code, :delivery_method, to: :user_phone_confirmation_session

    def too_many_otp_sends_response
      FormResponse.new(
        success: false,
        extra: extra_analytics_attributes,
      )
    end

    def rate_limit_exceeded?
      if otp_rate_limiter.exceeded_otp_send_limit?
        otp_rate_limiter.lock_out_user
        return @user_locked_out = true
      end
      false
    end

    def otp_rate_limiter
      @otp_rate_limiter ||= OtpRateLimiter.new(
        user: user,
        phone: phone,
        phone_confirmed: true,
      )
    end

    def send_otp
      idv_session.user_phone_confirmation_session = user_phone_confirmation_session.regenerate_otp
      @telephony_response = Telephony.send_confirmation_otp(
        otp: code,
        to: phone,
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
        otp_format: TwoFactorAuthenticatable::OTP_FORMAT[:char],
        channel: delivery_method,
        domain: IdentityConfig.store.domain_name,
        country_code: parsed_phone.country,
        extra_metadata: {
          area_code: parsed_phone.area_code,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
          resend: nil,
        },
      )
      otp_sent_response
    end

    def otp_sent_response
      FormResponse.new(
        success: telephony_response.success?, extra: extra_analytics_attributes,
      )
    end

    def extra_analytics_attributes
      {
        otp_delivery_preference: delivery_method,
        country_code: parsed_phone.country,
        area_code: parsed_phone.area_code,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        rate_limit_exceeded: rate_limit_exceeded?,
        telephony_response: @telephony_response,
      }
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end
  end
end
