class SmsSenderOtpJob < ActiveJob::Base
  queue_as :sms

  def perform(code, mobile)
    send_otp(TwilioService.new, code, mobile)
  end

  private

  def send_otp(twilio_service, code, mobile)
    twilio_service.send_sms(
      to: mobile,
      body: otp_message(code)
    )
  end

  def otp_message(code)
    "#{code} is your #{APP_NAME} one-time password."
  end
end
