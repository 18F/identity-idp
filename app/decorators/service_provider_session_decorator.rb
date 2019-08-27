class ServiceProviderSessionDecorator # rubocop:disable Metrics/ClassLength
  include ActionView::Helpers::TranslationHelper

  DEFAULT_LOGO = 'generic.svg'.freeze
  CUSTOM_ALERT_SP_NAMES = ['CBP Trusted Traveler Programs',
                           'FMCSA National Registry',
                           'The FMCSA Drug & Alcohol Clearinghouse'].freeze
  DEFAULT_ALERT_SP_NAMES = ['USAJOBS', 'SAM', 'HOMES.mil', 'HOMES.mil - test', 'Rule 19d-1'].freeze

  # These are SPs that are migrating users and require special help messages
  CUSTOM_SP_ALERTS = {
    'CBP Trusted Traveler Programs' => {
      i18n_name: 'trusted_traveler',
      learn_more: 'https://login.gov/help/trusted-traveler-programs/sign-in-doesnt-work/',
      exclude_paths: ['/sign_up/enter_email'],
    },
    'FMCSA National Registry' => {
      i18n_name: 'fmcsa_natl_registry',
      learn_more: 'https://login.gov/help/',
      exclude_paths: ['/es', '/fr'],
    },
    'The FMCSA Drug & Alcohol Clearinghouse' => {
      i18n_name: 'fmcsa_drug_alcohol_clearinghouse',
      exclude_paths: ['/es', '/fr'],
    },
  }.freeze

  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

  delegate :redirect_uris, to: :sp, prefix: true

  # :reek:DuplicateMethodCall
  # rubocop:disable Style/StringLiterals, Metrics/LineLength, Rails/OutputSafety
  def sp_msg(section, args = {})
    args = args.merge(sp_name: sp_name)
    args = args.merge(sp_create_link: sp_create_link)
    return t("service_providers.#{sp_alert_name}.#{section}", args).html_safe if sp.friendly_name == "The FMCSA Drug & Alcohol Clearinghouse" && custom_alert?
    return t("service_providers.#{sp_alert_name}.#{section}", args) if custom_alert?

    t("service_providers.default.#{section}", args)
  end
  # rubocop:enable Style/StringLiterals, Metrics/LineLength, Rails/OutputSafety

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

  def sp_create_link
    view_context.link_to t('service_providers.default.account_page.create_link'),
                         view_context.sign_up_email_path(request_id: sp_session[:request_id])
  end

  def sp_name
    sp.friendly_name || sp.agency
  end

  def sp_agency
    sp.agency || sp.friendly_name
  end

  def sp_return_url
    if sp.redirect_uris.present? && valid_oidc_request?
      URIService.add_params(
        oidc_redirect_uri,
        error: 'access_denied',
        state: request_params[:state],
      )
    else
      sp.return_to_sp_url
    end
  end

  def cancel_link_url
    view_context.new_user_session_url(request_id: sp_session[:request_id])
  end

  def failure_to_proof_url
    sp.failure_to_proof_url || sp_return_url
  end

  def sp_alert?(path)
    custom_alert? ? alert_not_excluded_for_path?(path) : default_alert?
  end

  def sp_alert_name
    CUSTOM_SP_ALERTS.dig(sp_name, :i18n_name)
  end

  def sp_alert_learn_more
    custom_alert? ? CUSTOM_SP_ALERTS.dig(sp_name, :learn_more) : 'https://login.gov/help/'
  end

  # :reek:DuplicateMethodCall
  def mfa_expiration_interval
    aal_1_expiration = Figaro.env.remember_device_expiration_hours_aal_1.to_i.hours
    aal_2_expiration = Figaro.env.remember_device_expiration_hours_aal_2.to_i.hours
    return aal_2_expiration if sp_aal > 1
    return aal_2_expiration if sp_ial > 1
    aal_1_expiration
  end

  def exclude_learn_more?
    sp.friendly_name == 'The FMCSA Drug & Alcohol Clearinghouse'
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def sp_aal
    sp.aal || 1
  end

  def sp_ial
    sp.ial || 1
  end

  def custom_alert?
    CUSTOM_ALERT_SP_NAMES.include?(sp_name)
  end

  def default_alert?
    DEFAULT_ALERT_SP_NAMES.include?(sp_name)
  end

  def alert_not_excluded_for_path?(path)
    !CUSTOM_SP_ALERTS[sp_name][:exclude_paths]&.include?(path)
  end

  def request_url
    sp_session[:request_url] || service_provider_request.url
  end

  def valid_oidc_request?
    return false if request_url.nil?
    authorize_form.valid?
  end

  def authorize_form
    OpenidConnectAuthorizeForm.new(request_params)
  end

  def oidc_redirect_uri
    request_params[:redirect_uri]
  end

  def request_params
    @request_params ||= URIService.params(request_url)
  end
end
