class VoiceOtpSenderJob < ActiveJob::Base
  queue_as :voice

  def perform(code:, phone:, otp_created_at:)
    send_otp(TwilioService.new, code, phone) if otp_valid?(otp_created_at)
  end

  private

  def otp_valid?(otp_created_at)
    time_zone = Time.zone
    time_zone.now < time_zone.parse(otp_created_at) + Devise.direct_otp_valid_for
  end

  def send_otp(twilio_service, code, phone)
    code_with_pauses = code.scan(/\d/).join(', ')
    twilio_service.place_call(
      to: phone,
      url: twimlet_url(code_with_pauses),
      record: Figaro.env.twilio_record_voice == 'true'
    )
  end

  def twimlet_url(code) # rubocop:disable Metrics/MethodLength
    repeat = message_repeat(code)

    twimlet_menu(
      repeat,
      1 => twimlet_menu(
        repeat,
        1 => twimlet_menu(
          repeat,
          1 => twimlet_menu(repeat, 1 => twimlet_message(message_final(code)))
        )
      )
    )
  end

  def message_repeat(code)
    I18n.t('jobs.voice_otp_sender_job.message_repeat', code: code)
  end

  def message_final(code)
    I18n.t('jobs.voice_otp_sender_job.message_final', code: code)
  end

  def twimlet_message(message)
    'https://twimlets.com/message?' + { Message: { 0 => message } }.to_query
  end

  def twimlet_menu(message, options)
    'https://twimlets.com/menu?' + {
      Message: message,
      Options: options.to_h,
    }.to_query
  end
end
