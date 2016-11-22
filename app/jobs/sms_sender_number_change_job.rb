class SmsSenderNumberChangeJob < ActiveJob::Base
  include Rails.application.routes.url_helpers
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
    I18n.t(
      'jobs.sms_sender_number_change_job.message',
      app: APP_NAME,
      support_url: contact_url
    )
  end
end
