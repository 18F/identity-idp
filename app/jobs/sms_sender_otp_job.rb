class SmsSenderOtpJob < ActiveJob::Base
  queue_as :sms

  def perform(code, mobile)
    send_otp(TwilioService.new, code, mobile)
  end

  private

  def send_otp(twilio_service, code, mobile)
    twilio_service.send_sms(
      to: mobile,
      body: "#{code} is your #{APP_NAME} one-time passcode."
    )
  end
end
