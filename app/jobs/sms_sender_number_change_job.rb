class SmsSenderNumberChangeJob < ActiveJob::Base
  queue_as :sms

  def perform(phone)
    number_change(TwilioService.new, phone)
  end

  private

  def number_change(twilio_service, phone)
    twilio_service.send_sms(
      to: phone,
      body: number_change_message
    )
  end

  def number_change_message
    <<-END.strip_heredoc
      You have changed the phone number for your #{APP_NAME} Account.

      If you did not request this change, please contact #{APP_NAME} at #{Figaro.env.support_url}.
    END
  end
end
