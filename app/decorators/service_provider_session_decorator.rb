class ServiceProviderSessionDecorator
  DEFAULT_LOGO = 'generic.svg'.freeze

  def initialize(sp:, view_context:)
    @sp = sp
    @view_context = view_context
  end

  def sp_logo
    if sp_logo_file_exist?
      sp.logo
    else
      DEFAULT_LOGO
    end
  end

  def return_to_service_provider_partial
    'devise/sessions/return_to_service_provider'
  end

  def nav_partial
    'shared/nav_branded'
  end

  def registration_heading
    sp = ActionController::Base.helpers.content_tag(:strong, sp_name)
    ActionController::Base.helpers.safe_join(
      [I18n.t('headings.create_account_with_sp', sp: sp).html_safe]
    )
  end

  def new_session_heading
    I18n.t('headings.sign_in_with_sp', sp: sp_name)
  end

  def verification_method_choice
    I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name)
  end

  def idv_hardfail4_partial
    'verify/hardfail4'
  end

  def sp_name
    sp.friendly_name || sp.agency
  end

  def sp_return_url
    sp.return_to_sp_url
  end

  private

  attr_reader :sp, :view_context

  def sp_logo_file_exist?
    rails_app = Rails.application

    if Rails.configuration.assets.compile
      rails_app.precompiled_assets.include?(sp_logo_path)
    else
      rails_app.assets_manifest.assets[sp_logo_path].present?
    end
  end

  def sp_logo_path
    "sp-logos/#{sp.logo}"
  end
end
