class UspsDecorator
  attr_reader :idv_session

  def initialize(idv_session)
    @idv_session = idv_session
  end

  def title
    letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
  end

  def button
    letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
  end

  private

  def letter_already_sent?
    @idv_session.address_verification_mechanism == 'usps'
  end
end
