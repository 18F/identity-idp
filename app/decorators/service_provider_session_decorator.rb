class ServiceProviderSessionDecorator # rubocop:disable Metrics/ClassLength
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  DEFAULT_LOGO = 'generic.svg'.freeze

  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

  delegate :redirect_uris, to: :sp, prefix: true

  def sp_msg(section, args = {})
    args = args.merge(sp_name: sp_name)
    args = args.merge(sp_create_link: sp_create_link)
    generate_custom_alert(section, args)
  end

  def generate_custom_alert(section, args)
    language = I18n.locale.to_s
    help_text = sp.help_text.dig(section, language)
    help_text % args if help_text
  end

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

  # rubocop:disable Metrics/AbcSize
  #:reek:DuplicateMethodCall :reek:TooManyStatements
  def sp_alert?(path)
    sign_in_path =
      I18n.locale == :en ? new_user_session_path : new_user_session_path(locale: I18n.locale)
    sign_up_path =
      I18n.locale == :en ? sign_up_email_path : sign_up_email_path(locale: I18n.locale)
    forgot_password_path =
      I18n.locale == :en ? new_user_password_path : new_user_password_path(locale: I18n.locale)
    path_to_section_map = { sign_in_path => 'sign_in',
                            sign_up_path => 'sign_up',
                            forgot_password_path => 'forgot_password' }
    custom_alert?(path_to_section_map[path])
  end
  # rubocop:enable Metrics/AbcSize

  # :reek:DuplicateMethodCall
  def mfa_expiration_interval
    aal_1_expiration = Figaro.env.remember_device_expiration_hours_aal_1.to_i.hours
    aal_2_expiration = Figaro.env.remember_device_expiration_hours_aal_2.to_i.hours
    return aal_2_expiration if sp_aal > 1
    return aal_2_expiration if sp_ial > 1
    aal_1_expiration
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def sp_aal
    sp.aal || 1
  end

  def sp_ial
    sp.ial || 1
  end

  def custom_alert?(section)
    language = I18n.locale.to_s
    sp.help_text[section]&.dig(language).present?
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
