class SmsSenderConfirmationJob < ActiveJob::Base
  queue_as :sms

  def perform(code, mobile)
    send_confirmation(TwilioSmsService.new, code, mobile)
  end

  private

  def send_confirmation(service, code, mobile)
    service.send_sms(
      to: mobile,
      body: "Your #{APP_NAME} phone confirmation code is: #{code}."
    )
  end
end
