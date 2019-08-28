module TwilioHelper
  def last_sms_otp(phone: nil)
    Telephony::Test::Message.last_otp(phone: phone)
  end

  def last_voice_otp(phone: nil)
    Telephony::Test::Call.last_otp(phone: phone)
  end

  def last_phone_otp
    [
      Telephony::Test::Message.messages,
      Telephony::Test::Call.calls,
    ].flatten.compact.sort_by(&:sent_at).reverse.each do |message_or_call|
      otp = message_or_call.otp
      return otp if otp.present?
    end
    nil
  end
end
