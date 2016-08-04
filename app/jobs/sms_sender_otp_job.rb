class SmsSenderOtpJob < ActiveJob::Base
  queue_as :sms

  def perform(code, phone)
    send_otp(TwilioSmsService.new, code, phone)
  end

  private

  def send_otp(twilio_service, code, phone)
    twilio_service.send_sms(
      to: phone,
      body: "#{code} is your #{APP_NAME} one-time passcode."
    )
  end
end
