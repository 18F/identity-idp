class SessionDecorator
  include Rails.application.routes.url_helpers
  include LocaleHelper

  def return_to_service_provider_partial
    'shared/null'
  end

  def return_to_sp_from_start_page_partial
    'shared/null'
  end

  def nav_partial
    'shared/nav_lite'
  end

  def registration_heading
    'sign_up/registrations/registration_heading'
  end

  def new_session_heading
    I18n.t('headings.sign_in_without_sp')
  end

  def verification_method_choice
    I18n.t('idv.messages.select_verification_without_sp')
  end

  def idv_hardfail4_partial
    'idv/no_sp_hardfail'
  end

  def cancel_link_url
    root_url(locale: locale_url_param)
  end

  def sp_name; end

  def sp_agency; end

  def sp_logo; end

  def sp_redirect_uris; end

  def sp_return_url; end

  def requested_attributes; end

  def sp_alert?; end

  def sp_alert_name; end

  def sp_alert_learn_more; end
end
