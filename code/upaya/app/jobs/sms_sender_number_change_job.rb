class SmsSenderNumberChangeJob < ActiveJob::Base
  queue_as :sms_sender

  def perform(user)
    twilio_service = TwilioService.new
    send(:number_change, twilio_service, user)
  end

  private

  def number_change(twilio_service, user)
    twilio_service.send_sms(
      to: user.mobile,
      body: number_change_message
    )
  end

  def number_change_message
    <<-END.strip_heredoc
      You have changed the phone number for your Upaya Account.

      If you did not request this change, please contact Upaya at https://upaya.18f.gov/contact
    END
  end
end
