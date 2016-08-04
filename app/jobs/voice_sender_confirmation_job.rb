class VoiceSenderConfirmationJob < ActiveJob::Base
  queue_as :voice

  def perform(code, phone)
    send_confirmation(TwilioVoiceService.new, code, phone)
  end

  private

  def send_confirmation(twilio_service, code, phone)
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
    "Message%5B0%5D=#{URI.escape(confirmation_message(code))}"
  end

  def confirmation_message(code)
    "Hello. Your #{APP_NAME} confirmation code is, " \
    "#{code}.  Again, your confirmation code is #{code}." \
    "Thank you, goodbye!"
  end
end
