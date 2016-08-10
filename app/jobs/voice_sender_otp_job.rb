class VoiceSenderOtpJob < ActiveJob::Base
  queue_as :voice

  def perform(code, phone)
    send_otp(TwilioService.new, code, phone)
  end

  private

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
    I18n.t('voice.otp_confirmation', code: code)
  end
end
