class SmsOtpSenderJob < ApplicationJob
  queue_as :sms

  def perform(code:, phone:, otp_created_at:)
    send_otp(TwilioService.new, code, phone) if otp_valid?(otp_created_at)
  end

  private

  def otp_valid?(otp_created_at)
    time_zone = Time.zone
    time_zone.now < time_zone.parse(otp_created_at) + Devise.direct_otp_valid_for
  end

  def send_otp(twilio_service, code, phone)
    twilio_service.send_sms(
      to: phone,
      body: I18n.t('jobs.sms_otp_sender_job.message', code: code, app: APP_NAME)
    )
  end
end
