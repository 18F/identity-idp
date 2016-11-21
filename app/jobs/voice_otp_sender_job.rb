class VoiceOtpSenderJob < ActiveJob::Base
  include Rails.application.routes.url_helpers

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
      url: BasicAuthUrl.build(voice_otp_url(code: code))
    )
  end
end
