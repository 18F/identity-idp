class SmsTextMailerPreview < ActionMailer::Preview
  def daily_voice_limit_reached
    SmsTextMailer.daily_voice_limit_reached
  end

  def account_deleted_notice
    SmsTextMailer.account_deleted_notice
  end
end
