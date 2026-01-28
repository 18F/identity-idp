# frozen_string_literal: true

class SmsTextMailer < ActionMailer::Base
  def account_deleted_notice
    mail_to
  end

  def daily_voice_limit_reached
    mail_to
  end

  private

  def mail_to
    mail to: 'NO EMAIL'
  end
end
