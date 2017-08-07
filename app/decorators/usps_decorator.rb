class UspsDecorator
  attr_reader :usps_mail_service

  def initialize(usps_mail_service)
    @usps_mail_service = usps_mail_service
  end

  def title
    letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
  end

  def button
    letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
  end

  private

  def letter_already_sent?
    @usps_mail_service.any_mail_sent?
  end
end
