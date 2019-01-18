class SmsPersonalKeySignInNotifierJob < ApplicationJob
  queue_as :sms

  # :reek:UtilityFunction
  def perform(phone:)
    TwilioService::Utils.new.send_sms(
      to: phone,
      body: I18n.t(
        'jobs.sms_personal_key_sign_in_notifier_job.message',
        app: APP_NAME,
      ),
    )
  end
end
