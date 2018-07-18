class SmsAccountResetCancellationNotifierJob < ApplicationJob
  queue_as :sms

  def perform(phone:)
    TwilioService::Utils.new.send_sms(
      to: phone,
      body: I18n.t(
        'jobs.sms_account_reset_cancel_job.message',
        app: APP_NAME
      )
    )
  end
end
