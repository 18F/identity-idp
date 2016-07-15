class SmsSenderConfirmationJob < ActiveJob::Base
  queue_as :sms

  def perform(code, mobile)
    TwilioService.new.send_sms(
      to: mobile,
      body: "Your #{APP_NAME} phone confirmation code is: #{code}."
    )
  end
end
