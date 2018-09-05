class ServiceProviderSessionDecorator
  DEFAULT_LOGO = 'generic.svg'.freeze

  SP_ALERTS = {
    'CBP Trusted Traveler Programs' => {
      i18n_name: 'trusted_traveler',
      learn_more: 'https://login.gov/help/trusted-traveler-programs/sign-in-doesnt-work/',
      exclude_paths: ['/sign_up/enter_email'],
    },
    'USAJOBS' => {
      i18n_name: 'usa_jobs',
      learn_more: 'https://login.gov/help/',
    },
    'SAM' => {
      i18n_name: 'sam',
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

  def sp_logo_url
    logo = sp_logo
    if RemoteSettingsService.remote?(logo)
      logo
    else
      ActionController::Base.helpers.image_path("sp-logos/#{logo}")
    end
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
    if sp.redirect_uris.present? && request_url.is_a?(String) && openid_connect_redirector.valid?
      openid_connect_redirector.decline_redirect_uri
    else
      sp.return_to_sp_url
    end
  end

  def cancel_link_url
    view_context.sign_up_start_url(request_id: sp_session[:request_id])
  end

  def failure_to_proof_url
    sp.failure_to_proof_url || sp_return_url
  end

  def sp_alert?(path)
    sp_alert.present? && !sp_alert[:exclude_paths]&.include?(path)
  end

  def sp_alert_name
    SP_ALERTS.dig(sp_name, :i18n_name)
  end

  def sp_alert_learn_more
    SP_ALERTS.dig(sp_name, :learn_more)
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def sp_alert
    @sp_alert ||= SP_ALERTS[sp_name]
  end

  def request_url
    sp_session[:request_url] || service_provider_request.url
  end

  def openid_connect_redirector
    @_openid_connect_redirector ||= OpenidConnectRedirector.from_request_url(request_url)
  end
end
