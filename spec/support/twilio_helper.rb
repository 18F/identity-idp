module TwilioHelper
  def last_sms_otp(phone: nil)
    Twilio::FakeMessage.last_otp(phone: phone)
  end

  def last_international_sms_otp(phone: nil)
    Twilio::FakeVerifyMessage.last_otp(phone: phone)
  end

  def last_voice_otp(phone: nil)
    Twilio::FakeCall.last_otp(phone: phone)
  end

  def last_phone_otp
    [
      Twilio::FakeMessage.last_message,
      Twilio::FakeCall.last_call,
      Twilio::FakeVerifyMessage.last_message,
    ].compact.max_by(&:sent_at)&.otp
  end
end
