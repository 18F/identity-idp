class VoiceOtpSenderJob < ApplicationJob
  include Rails.application.routes.url_helpers
  include LocaleHelper

  queue_as :voice

  # rubocop:disable Lint/UnusedMethodArgument
  # locale is an argument used for the Twilio/Authy Verify service, which uses
  # a localized message for delivering OTPs via SMS and Voice. As of this
  # writing, we are only using Verify for non-US SMS, but we might expand
  # to Voice later.
  def perform(code:, phone:, otp_created_at:, locale: nil)
    send_otp(TwilioService::Utils.new, code, phone) if otp_valid?(otp_created_at)
  end
  # rubocop:enable Lint/UnusedMethodArgument

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
          locale: locale_url_param,
        ),
      ),
      record: Figaro.env.twilio_record_voice == 'true',
    )
  end

  def cipher
    Gibberish::AES.new(Figaro.env.attribute_encryption_key)
  end
end
