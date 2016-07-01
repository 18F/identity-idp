class SmsSenderExistingMobileJob < ActiveJob::Base
  queue_as :sms

  def perform(mobile)
    existing_mobile(TwilioService.new, mobile)
  end

  private

  def existing_mobile(twilio_service, mobile)
    twilio_service.send_sms(
      to: mobile,
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
