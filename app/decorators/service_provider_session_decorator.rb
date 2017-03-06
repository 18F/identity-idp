class ServiceProviderSessionDecorator
  attr_reader :sp_name

  def initialize(sp:, view_context:)
    @sp = sp
    @view_context = view_context
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

  def sp_name
    sp.friendly_name || sp.agency
  end

  def registration_heading
    sp = ActionController::Base.helpers.content_tag(:strong, sp_name)
    ActionController::Base.helpers.safe_join(
      [I18n.t('headings.create_account_with_sp', sp: sp).html_safe]
    )
  end

  def idv_hardfail4_partial
    'verify/hardfail4'
  end

  def logo_partial
    return 'shared/nav_branded_logo' if sp.logo

    'shared/null'
  end

  def timeout_flash_text
    I18n.t(
      'notices.session_cleared_with_sp',
      link: view_context.link_to(sp_name, sp.return_to_sp_url),
      minutes: Figaro.env.session_timeout_in_minutes,
      sp: sp_name
    )
  end

  private

  attr_reader :sp, :view_context
end
