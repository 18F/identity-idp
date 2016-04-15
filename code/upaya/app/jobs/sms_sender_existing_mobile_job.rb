class SmsSenderExistingMobileJob < ActiveJob::Base
  queue_as :sms

  def perform(user)
    twilio_service = TwilioService.new
    send(:existing_mobile, twilio_service, user)
  end

  private

  def existing_mobile(twilio_service, user)
    twilio_service.send_sms(
      to: user.mobile,
      body: existing_mobile_message
    )
  end

  def existing_mobile_message
    <<-END.strip_heredoc
      A request was made to use this number to receive one-time passwords from Upaya.

      This number is already set up to receive one-time passwords.

      If you did not make this request, please contact Upaya at https://upaya.18f.gov/contact
    END
  end
end
