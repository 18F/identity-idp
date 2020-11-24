class ServiceProviderSessionDecorator
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

  def remember_device_default
    sp_aal < 2
  end

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
    if sp.logo.present?
      sp.logo
    else
      DEFAULT_LOGO
    end
  end

  def sp_logo_url
    if FeatureManagement.logo_upload_enabled? && sp.remote_logo_key.present?
      s3_logo_url(sp)
    else
      legacy_logo_url
    end
  end

  def s3_logo_url(service_provider)
    region = AppConfig.env.aws_region
    bucket = AppConfig.env.aws_logo_bucket
    key = service_provider.remote_logo_key

    "https://s3.#{region}.amazonaws.com/#{bucket}/#{key}"
  end

  def legacy_logo_url
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
    sp.friendly_name || sp.agency&.name
  end

  def sp_return_url
    if sp.redirect_uris.present? && valid_oidc_request?
      UriService.add_params(
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
    sp.failure_to_proof_url.presence || sp_return_url
  end

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

  def mfa_expiration_interval
    aal_1_expiration = AppConfig.env.remember_device_expiration_hours_aal_1.to_i.hours
    aal_2_expiration = AppConfig.env.remember_device_expiration_hours_aal_2.to_i.hours
    return aal_2_expiration if sp_aal > 1
    return aal_2_expiration if sp_ial > 1
    aal_1_expiration
  end

  def requested_more_recent_verification?
    return false if authorize_form.verified_within.blank?

    verified_at = view_context.current_user.active_profile&.verified_at
    !verified_at || verified_at < authorize_form.verified_within.ago
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
    @request_params ||= UriService.params(request_url)
  end
end
