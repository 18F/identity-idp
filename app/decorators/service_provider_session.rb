class ServiceProviderSession
  include ActionView::Helpers::TranslationHelper
  include Rails.application.routes.url_helpers

  DEFAULT_LOGO = 'generic.svg'.freeze

  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

  def remember_device_default
    sp_aal < 2
  end

  def sp_redirect_uris
    @sp.redirect_uris
  end

  def sp_logo
    sp.logo.presence || DEFAULT_LOGO
  end

  def sp_logo_url
    if FeatureManagement.logo_upload_enabled? && sp.remote_logo_key.present?
      s3_logo_url(sp)
    else
      legacy_logo_url
    end
  end

  def s3_logo_url(service_provider)
    region = IdentityConfig.store.aws_region
    bucket = IdentityConfig.store.aws_logo_bucket
    key = service_provider.remote_logo_key

    "https://s3.#{region}.amazonaws.com/#{bucket}/#{key}"
  end

  def legacy_logo_url
    logo = sp_logo
    ActionController::Base.helpers.image_path("sp-logos/#{logo}")
  rescue Propshaft::MissingAssetError
    ''
  end

  def new_session_heading
    I18n.t('headings.sign_in_with_sp', sp: sp_name)
  end

  def verification_method_choice
    I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name)
  end

  def requested_attributes
    (sp_session[:requested_attributes] || service_provider_request.requested_attributes).sort
  end

  def sp_create_link
    view_context.sign_up_email_path(request_id: sp_session[:request_id])
  end

  def sp_name
    sp.friendly_name || sp.agency&.name
  end

  def sp_issuer
    sp.issuer
  end

  def selfie_required?
    return false if Identity::Hostdata.env == 'prod'

    !!(IdentityConfig.store.doc_auth_selfie_capture_enabled &&
      sp_session[:biometric_comparison_required])
  end

  def cancel_link_url
    view_context.new_user_session_url(request_id: sp_session[:request_id])
  end

  def sp_alert(section)
    return if sp.help_text.nil?
    language = I18n.locale.to_s
    alert = sp.help_text.dig(section, language)
    if alert.present?
      format(alert, sp_name: sp_name, sp_create_link: sp_create_link, app_name: APP_NAME)
    end
  end

  def mfa_expiration_interval
    aal_1_expiration = IdentityConfig.store.remember_device_expiration_hours_aal_1.hours
    aal_2_expiration = IdentityConfig.store.remember_device_expiration_minutes_aal_2.minutes
    return aal_2_expiration if sp_aal > 1
    return aal_2_expiration if sp_ial > 1
    return aal_2_expiration if requested_aal > 1

    aal_1_expiration
  end

  def requested_more_recent_verification?
    unless IdentityConfig.store.allowed_verified_within_providers.include?(sp_issuer)
      return false
    end
    return false if authorize_form.verified_within.blank?

    verified_at = view_context.current_user.active_profile&.verified_at
    !verified_at || verified_at < authorize_form.verified_within.ago
  end

  def url_options
    if @view_context.respond_to?(:url_options)
      @view_context.url_options
    else
      LinkLocaleResolver.locale_options
    end
  end

  def request_url_params
    @request_url_params ||= begin
      if request_url.present?
        UriService.params(request_url)
      else
        {}
      end
    end
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def sp_aal
    sp.default_aal || 1
  end

  def sp_ial
    sp.ial || 1
  end

  def requested_aal
    sp_session[:aal_level_requested] || 1
  end

  def request_url
    sp_session[:request_url] || service_provider_request.url
  end

  def authorize_form
    OpenidConnectAuthorizeForm.new(request_url_params)
  end
end
