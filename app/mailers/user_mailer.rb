class UserMailer < ActionMailer::Base
  before_action :attach_images
  default from: Figaro.env.email_from

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

  def contact_request(details)
    @details = details
    mail(to: Figaro.env.support_email, subject: t('mailer.contact_request.subject'))
  end

  def attach_images
    attachments.inline['logo.png'] = File.read('app/assets/images/logo.png')
  end
end
