class UserSmsTextMailerPreview < ActionMailer::Preview
  def daily_voice_limit_reached
    UserSmsTextMailer.daily_voice_limit_reached
  end

  def account_deleted_notice
    UserSmsTextMailer.account_deleted_notice
  end
end
