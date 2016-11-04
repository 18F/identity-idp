class VoiceOtpSenderJob < ActiveJob::Base
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
    code_with_pauses = code.scan(/\d/).join(', ')
    twilio_service.place_call(
      to: phone,
      url: twimlet_url(code_with_pauses)
    )
  end

  def twimlet_url(code)
    "https://twimlets.com/message?#{twimlet_query_string(code)}"
  end

  def twimlet_query_string(code)
    "Message%5B0%5D=#{URI.escape(otp_message(code))}"
  end

  def otp_message(code)
    I18n.t('jobs.voice_otp_sender_job.message', code: code)
  end
end
