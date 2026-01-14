class SmsTextMailerPreview < ActionMailer::Preview
  def daily_voice_limit_reached
    SmsTextMailer.daily_voice_limit_reached
  end
end
