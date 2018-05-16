class ServiceProviderSessionDecorator
  include Rails.application.routes.url_helpers
  include LocaleHelper

  DEFAULT_LOGO = 'generic.svg'.freeze

  SP_ALERTS = {
    'CBP Trusted Traveler Programs' => {
      i18n_name: 'trusted_traveler',
      learn_more: 'https://login.gov/help/trusted-traveler-programs/sign-in-doesnt-work/',
    },
    'USAJOBS' => {
      i18n_name: 'usa_jobs',
      learn_more: 'https://login.gov/help/',
    },
    'Railroad Retirement Board' => {
      i18n_name: 'railroad_retirement_board',
      learn_more: 'https://login.gov/help/',
    },
    'U.S. Railroad Retirement Board Benefit Connect' => {
      i18n_name: 'railroad_retirement_board',
      learn_more: 'https://login.gov/help/',
    },
  }.freeze

  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

  delegate :redirect_uris, to: :sp, prefix: true

  def sp_logo
    sp.logo || DEFAULT_LOGO
  end

  def return_to_service_provider_partial
    if sp_return_url.present?
      'devise/sessions/return_to_service_provider'
    else
      'shared/null'
    end
  end

  def return_to_sp_from_start_page_partial
    if sp_return_url.present?
      'sign_up/registrations/return_to_sp_from_start_page'
    else
      'shared/null'
    end
  end

  def nav_partial
    'shared/nav_branded'
  end

  def new_session_heading
    I18n.t('headings.sign_in_with_sp', sp: sp_name)
  end

  def registration_heading
    'sign_up/registrations/sp_registration_heading'
  end

  def verification_method_choice
    I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name)
  end

  def idv_hardfail4_partial
    'idv/hardfail4'
  end

  def requested_attributes
    sp_session[:requested_attributes].sort
  end

  def sp_name
    sp.friendly_name || sp.agency
  end

  def sp_agency
    sp.agency || sp.friendly_name
  end

  def sp_return_url
    if sp.redirect_uris.present? && openid_connect_redirector.valid?
      openid_connect_redirector.decline_redirect_uri
    else
      sp.return_to_sp_url
    end
  end

  def cancel_link_url
    sign_up_start_url(request_id: sp_session[:request_id], locale: locale_url_param)
  end

  def sp_alert?
    SP_ALERTS[sp_name].present?
  end

  def sp_alert_name
    sp_alert? ? SP_ALERTS[sp_name][:i18n_name] : nil
  end

  def sp_alert_learn_more
    sp_alert? ? SP_ALERTS[sp_name][:learn_more] : nil
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def request_url
    sp_session[:request_url] || service_provider_request.url
  end

  def openid_connect_redirector
    @_openid_connect_redirector ||= OpenidConnectRedirector.from_request_url(request_url)
  end
end
