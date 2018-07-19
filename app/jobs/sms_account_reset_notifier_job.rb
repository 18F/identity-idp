class SmsAccountResetNotifierJob < ApplicationJob
  queue_as :sms
  include Rails.application.routes.url_helpers

  def perform(phone:, cancel_token:)
    TwilioService.new.send_sms(
      to: phone,
      body: I18n.t(
        'jobs.sms_account_reset_notifier_job.message',
        app: APP_NAME,
        cancel_link: account_reset_cancel_url(token: cancel_token)
      )
    )
  end
end
