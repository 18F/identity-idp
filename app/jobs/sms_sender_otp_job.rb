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
    <<-END.strip_heredoc
      You requested a secure one-time password to log in to your Upaya Account.

      Please enter this secure one-time password: #{code}
    END
  end
end
