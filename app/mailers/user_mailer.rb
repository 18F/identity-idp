class UserMailer < ActionMailer::Base
  include Mailable
  include LocaleHelper
  before_action :attach_images
  default from: email_with_name(Figaro.env.email_from, Figaro.env.email_from)

  def email_changed(old_email)
    mail(to: old_email, subject: t('mailer.email_change_notice.subject'))
  end

  def signup_with_your_email(email)
    @root_url = root_url(locale: locale_url_param)
    mail(to: email, subject: t('mailer.email_reuse_notice.subject'))
  end

  def password_changed(user)
    mail(to: user.email, subject: t('devise.mailer.password_updated.subject'))
  end

  def phone_changed(user)
    mail(to: user.email, subject: t('user_mailer.phone_changed.subject'))
  end

  def account_does_not_exist(email, request_id)
    @sign_up_email_url = sign_up_email_url(request_id: request_id, locale: locale_url_param)
    mail(to: email, subject: t('user_mailer.account_does_not_exist.subject'))
  end

  def reset_password(email)
    mail(to: email, subject: 'Please reset your password')
  end
end
