# frozen_string_literal: true

class SmsTextMailer < ActionMailer::Base
  def daily_voice_limit_reached
    @message = t('telephony.error.friendly_message.daily_voice_limit_reached')

    mail to: email
  end

  private

  def email
    'NO EMAIL'
  end
end
