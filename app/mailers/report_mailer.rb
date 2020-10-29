class ReportMailer < ActionMailer::Base
  include Mailable
  before_action :attach_images
  default from: email_with_name(Figaro.env.email_from, Figaro.env.email_from_display_name),
          reply_to: email_with_name(Figaro.env.email_from, Figaro.env.email_from_display_name)

  def sps_over_quota_limit(email)
    mail(to: email, subject: t('report_mailer.sps_over_quota_limit.subject'))
  end
end