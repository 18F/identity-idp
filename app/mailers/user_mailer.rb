class UserMailer < ActionMailer::Base
  before_action :attach_images
  default from: 'upaya@18f.gov'

  def email_changed(old_email)
    mail(to: old_email, subject: t('mailer.email_change_notice.subject'))
  end

  def signup_with_your_email(email)
    @root_url = root_url
    @new_user_password_url = new_user_password_url
    mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
  end

  def password_changed(user)
    mail(to: user.email, subject: t('devise.mailer.password_updated.subject'))
  end

  def attach_images
    attachments.inline['logo.png'] = File.read('app/assets/images/logo.png')
  end
end
