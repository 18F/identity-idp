class SmsOtpSenderJob < ApplicationJob
  queue_as :sms

  # rubocop:disable Lint/UnusedMethodArgument
  def perform(code:, phone:, otp_created_at:, locale: nil)
    return unless otp_valid?(otp_created_at)

    if us_number?
      send_sms_via_twilio_rest_api
    else
      send_sms_via_twilio_verify_api(locale)
    end
  end
  # rubocop:enable Lint/UnusedMethodArgument

  private

  def code
    arguments[0][:code]
  end

  def phone
    arguments[0][:phone]
  end

  def send_sms_via_twilio_rest_api
    TwilioService.new.send_sms(
      to: phone,
      body: I18n.t(
        'jobs.sms_otp_sender_job.message',
        code: code, app: APP_NAME, expiration: otp_valid_for_minutes
      )
    )
  end

  def send_sms_via_twilio_verify_api(locale)
    PhoneVerification.new(phone: phone, locale: locale, code: code).send_sms
  end

  def us_number?
    Phonelib.parse(phone).country == 'US'
  end

  def otp_valid?(otp_created_at)
    time_zone = Time.zone
    time_zone.now < time_zone.parse(otp_created_at) + Devise.direct_otp_valid_for
  end

  def otp_valid_for_minutes
    Devise.direct_otp_valid_for.to_i / 60
  end
end
