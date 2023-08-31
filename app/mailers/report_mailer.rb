class ReportMailer < ActionMailer::Base
  include Mailable

  before_action :attach_images

  def deleted_user_accounts_report(email:, name:, issuers:, data:)
    @name = name
    @issuers = issuers
    @data = data
    attachments['deleted_user_accounts.csv'] = data
    mail(to: email, subject: t('report_mailer.deleted_accounts_report.subject'))
  end

  def sp_issuer_user_counts_report(email:, issuer:, total:, ial1_total:, ial2_total:, name:)
    @name = name
    @issuer = issuer
    @total = total
    @ial1_total = ial1_total
    @ial2_total = ial2_total
    mail(to: email, subject: t('report_mailer.sp_issuer_user_counts_report.subject'))
  end

  def system_demand_report(email:, data:, name:)
    @name = name
    attachments['system_demand.csv'] = data
    mail(to: email, subject: t('report_mailer.system_demand_report.subject'))
  end
end
