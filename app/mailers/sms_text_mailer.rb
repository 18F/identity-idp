# frozen_string_literal: true

class SmsTextMailer < ActionMailer::Base
  def account_deleted_notice
    @message = t('telephony.account_deleted_notice', app_name: APP_NAME)

    mail_to
  end

  def daily_voice_limit_reached
    @message = t('telephony.error.friendly_message.daily_voice_limit_reached')

    mail_to
  end

  private

  def mail_to
    mail to: email
  end

  def email
    'NO EMAIL'
  end
end
