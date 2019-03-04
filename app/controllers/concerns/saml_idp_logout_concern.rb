require 'saml_idp/logout_response_builder'

module SamlIdpLogoutConcern
  extend ActiveSupport::Concern

  private

  def sign_out_with_flash
    track_logout_event
    sign_out if user_signed_in?
    flash[:success] = t('devise.sessions.signed_out')
    redirect_to root_url
  end

  def handle_valid_sp_logout_request
    render_template_for(
      Base64.strict_encode64(logout_response),
      saml_request.response_url,
      'SAMLResponse',
    )
    sign_out if user_signed_in?
  end

  def logout_response
    idp_config = SamlIdp.config
    SamlIdp::LogoutResponseBuilder.new(
      UUID.generate,
      idp_config.base_saml_location,
      saml_request.response_url,
      saml_request.request_id,
      idp_config.algorithm,
    ).signed
  end

  def track_logout_event
    sp_initiated = saml_request.present?
    analytics.track_event(
      Analytics::LOGOUT_INITIATED,
      sp_initiated: sp_initiated,
      oidc: false,
      saml_request_valid: sp_initiated ? valid_saml_request? : true,
    )
  end
end
