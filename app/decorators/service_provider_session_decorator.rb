class ServiceProviderSessionDecorator
  def initialize(sp_name:)
    @sp_name = sp_name
  end

  def return_to_service_provider_partial
    'devise/sessions/return_to_service_provider'
  end

  def nav_partial
    'shared/nav_branded'
  end

  def new_session_heading
    I18n.t('headings.sign_in_with_sp', sp: sp_name)
  end

  def registration_heading
    I18n.t('headings.create_account_with_sp', sp: sp_name)
  end

  def registration_bullet_1
    I18n.t('devise.registrations.start.bullet_1_with_sp', sp: sp_name)
  end

  def idv_hardfail4_partial
    'verify/hardfail4'
  end

  private

  attr_reader :sp_name
end
