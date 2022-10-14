class ReportMailer < ActionMailer::Base
  include Mailable

  before_action :attach_images

  def sps_over_quota_limit(email)
    mail(to: email, subject: t('report_mailer.sps_over_quota_limit.subject'))
  end

  def deleted_user_accounts_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['deleted_user_accounts.csv'] = data
    mail(to: email, subject: t('report_mailer.deleted_accounts_report.subject'))
  end
end
