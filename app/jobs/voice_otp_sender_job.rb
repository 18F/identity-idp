class VoiceOtpSenderJob < ApplicationJob
  include Rails.application.routes.url_helpers
  include LocaleHelper

  queue_as :voice

  def perform(code:, phone:, otp_created_at:)
    send_otp(TwilioService.new, code, phone) if otp_valid?(otp_created_at)
  end

  private

  def otp_valid?(otp_created_at)
    time_zone = Time.zone
    time_zone.now < time_zone.parse(otp_created_at) + Devise.direct_otp_valid_for
  end

  def send_otp(twilio_service, code, phone)
    twilio_service.place_call(
      to: phone,
      url: BasicAuthUrl.build(
        voice_otp_url(
          encrypted_code: cipher.encrypt(code),
          locale: locale_url_param
        )
      ),
      record: Figaro.env.twilio_record_voice == 'true'
    )
  end

  def cipher
    Gibberish::AES.new(Figaro.env.attribute_encryption_key)
  end
end
