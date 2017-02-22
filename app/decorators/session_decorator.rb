class SessionDecorator
  def return_to_service_provider_partial
    'shared/null'
  end

  def nav_partial
    'shared/nav_lite'
  end

  def registration_heading
    I18n.t('headings.create_account_without_sp')
  end

  def new_session_heading
    I18n.t('headings.sign_in_without_sp')
  end

  def idv_hardfail4_partial
    'shared/null'
  end

  def logo_partial; end
end
