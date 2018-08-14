module Idv
  # :reek:InstanceVariableAssumption
  class SendPhoneConfirmationOtpForm
    include ActiveModel::Model

    attr_accessor :user, :idv_session, :locale

    validates :otp_delivery_preference, inclusion: { in: %i[sms voice] }

    def initialize(user:, idv_session:, locale:)
      self.user = user
      self.idv_session = idv_session
      self.locale = locale
    end

    def submit
      return handle_valid_otp_delivery_preference if valid?
      FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
    end

    def user_locked_out?
      @user_locked_out
    end

    private

    def handle_valid_otp_delivery_preference
      otp_rate_limiter.reset_count_and_otp_last_sent_at if user.decorate.no_longer_locked_out?

      return too_many_otp_sends_response if rate_limit_exceeded?
      otp_rate_limiter.increment
      return too_many_otp_sends_response if rate_limit_exceeded?

      send_otp
      FormResponse.new(success: true, errors: {}, extra: extra_analytics_attributes)
    end

    def too_many_otp_sends_response
      FormResponse.new(
        success: false,
        errors: {},
        extra: extra_analytics_attributes
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
      @otp_rate_limiter ||= OtpRateLimiter.new(user: user, phone: phone)
    end

    def send_otp
      idv_session.phone_confirmation_otp = PhoneConfirmationOtpGenerator.generate_otp
      idv_session.phone_confirmation_otp_delivery_method = otp_delivery_preference
      idv_session.phone_confirmation_otp_sent_at = Time.zone.now.to_s
      if otp_delivery_preference == :sms
        send_sms_otp
      elsif otp_delivery_preference == :voice
        send_voice_otp
      end
    end

    def send_sms_otp
      SmsOtpSenderJob.perform_later(
        code: idv_session.phone_confirmation_otp,
        phone: phone,
        otp_created_at: idv_session.phone_confirmation_otp_sent_at,
        message: 'jobs.sms_otp_sender_job.verify_message',
        locale: locale
      )
    end

    def send_voice_otp
      VoiceOtpSenderJob.perform_later(
        code: idv_session.phone_confirmation_otp,
        phone: phone,
        otp_created_at: idv_session.phone_confirmation_otp_sent_at,
        locale: locale
      )
    end

    def phone
      @phone ||= PhoneFormatter.format(idv_session.params[:phone])
    end

    def otp_delivery_preference
      return :sms if PhoneNumberCapabilities.new(phone).sms_only?
      @otp_delivery_preference ||= idv_session.phone_confirmation_otp_delivery_method.to_sym
    end

    def extra_analytics_attributes
      parsed_phone = Phonelib.parse(phone)
      {
        otp_delivery_preference: otp_delivery_preference,
        country_code: parsed_phone.country_code,
        area_code: parsed_phone.area_code,
        rate_limit_exceeded: rate_limit_exceeded?,
      }
    end
  end
end
