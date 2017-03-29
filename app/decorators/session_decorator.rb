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

  def verification_method_choice
    I18n.t('idv.messages.select_verification_without_sp')
  end

  def idv_hardfail4_partial
    'shared/null'
  end

  def sp_name; end

  def sp_logo; end

  def sp_return_url; end
end
