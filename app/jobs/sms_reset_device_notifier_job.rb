class SmsResetDeviceNotifierJob < ApplicationJob
  queue_as :sms
  include Rails.application.routes.url_helpers

  def perform(phone:, cancel_token:)
    TwilioService.new.send_sms(
      to: phone,
      body: I18n.t(
        'jobs.sms_reset_device_notifier_job.message',
        app: APP_NAME,
        cancel_link: reset_device_cancel_url(token: cancel_token)
      )
    )
  end
end
