class ServiceProviderSessionDecorator
  include Rails.application.routes.url_helpers
  include ActionView::Helpers
  include ActionView::Helpers::TagHelper
  include LocaleHelper
  include ContentHelper

  DEFAULT_LOGO = 'generic.svg'.freeze

  def initialize(sp:, view_context:, sp_session:, service_provider_request:)
    @sp = sp
    @view_context = view_context
    @sp_session = sp_session
    @service_provider_request = service_provider_request
  end

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
    'verify/hardfail4'
  end

  def requested_attributes
    sp_session[:requested_attributes]
  end

  def sp_name
    sp.friendly_name || sp.agency
  end

  def sp_return_url
    if sp.redirect_uris.present? && openid_connect_redirector.valid?
      openid_connect_redirector.decline_redirect_uri
    else
      sp.return_to_sp_url
    end
  end

  def cancel_link_path
    sign_up_start_path(request_id: sp_session[:request_id])
  end

  def warning_point_text(app_flow)
    warning_qualifier = I18n.t("#{app_flow}.cancel.warning_qualifier")
    warning_qualifier_tag = content_tag(:span, warning_qualifier, class: 'italic')

    warning_point_text_t_sp(app_flow, warning_qualifier_tag)
  end

  private

  attr_reader :sp, :view_context, :sp_session, :service_provider_request

  def warning_point_text_t_sp(app_flow, warning_qualifier_tag)
    sp_name_tag = content_tag(:span, sp_name, class: 'bold')
    warning_point_text = I18n.t(
      "#{app_flow}.cancel.warning_point",
      sp_name: sp_name_tag,
      warning_qualifier: warning_qualifier_tag
    )
    safe_join(split_tag(
                split_tag(warning_point_text, sp_name_tag),
                warning_qualifier_tag
    ))
  end

  def request_url
    sp_session[:request_url] || service_provider_request.url
  end

  def openid_connect_redirector
    @_openid_connect_redirector ||= OpenidConnectRedirector.from_request_url(request_url)
  end
end
