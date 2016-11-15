class SessionDecorator
  def return_to_service_provider_partial
    'shared/null'
  end

  def nav_partial
    'shared/nav_lite'
  end

  def new_session_heading
    I18n.t('headings.log_in')
  end

  def registration_heading
    I18n.t('headings.create_account_without_sp')
  end

  def registration_bullet_1
    I18n.t('devise.registrations.start.bullet_1_without_sp')
  end

  def idv_hardfail4_partial
    'shared/null'
  end
end
