class UserMailer < ActionMailer::Base
  default from: 'upaya@18f.gov'

  def already_confirmed(user)
    @root_url = root_url
    @new_user_password_url = new_user_password_url
    mail(
      to: user.email,
      subject: t('upaya.mailer.already_confirmed.subject', app_name: APP_NAME)
    )
  end

  def email_changed(old_email)
    mail(to: old_email, subject: t('upaya.mailer.email_change_notice.subject'))
  end

  def signup_with_your_email(email)
    @root_url = root_url
    @new_user_password_url = new_user_password_url
    mail(to: email, subject: t('upaya.mailer.email_reuse_notice.subject'))
  end

  def password_changed(user)
    mail(to: user.email, subject: t('devise.mailer.password_updated.subject'))
  end

  def password_expiry(user)
    @link_url = edit_user_registration_url
    mail(to: user.email, subject: t('upaya.mailer.password_expires_soon.subject'))
  end
end
