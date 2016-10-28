class SessionDecorator
  def registration_heading
    I18n.t('headings.create_account_without_sp')
  end

  def registration_bullet_1
    I18n.t('devise.registrations.start.bullet_1_without_sp')
  end
end
