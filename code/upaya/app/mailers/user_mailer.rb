class UserMailer < ActionMailer::Base
  default from: 'upaya@18f.gov'

  def email_changed(old_email)
    mail(to: old_email, subject: 'Email change notification')
  end

  def signup_with_your_email(user)
    @root_url = root_url
    @new_user_password_url = new_user_password_url
    mail(to: user.email, subject: 'Email Confirmation Notification')
  end

  def password_changed(user)
    mail(to: user.email, subject: t('devise.mailer.password_updated.subject'))
  end

  def security_questions_attempts_exceeded(user)
    mail(to: user.email, subject: t('devise.mailer.account_locked.subject'))
  end

  def password_expiry(user)
    @link_url = edit_user_registration_url
    mail(to: user.email, subject: t('upaya.mailer.password_expires_soon.subject'))
  end
end
