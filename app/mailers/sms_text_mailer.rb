# frozen_string_literal: true

class SmsTextMailer < ActionMailer::Base
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.sms_text_mailer.daily_voice_limit_reached.subject
  #
  def daily_voice_limit_reached
    @message = t('telephony.error.friendly_message.daily_voice_limit_reached')

    mail to: 'NO EMAIL'
  end
end
