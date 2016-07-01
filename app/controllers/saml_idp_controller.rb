require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern

  skip_before_action :verify_authenticity_token

  before_action :disable_caching
  before_action :apply_secure_headers_override, only: [:auth, :logout]

  def auth
    link_identity_from_session_data

    return redirect_to idv_url if identity_needs_verification?

    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
  end

  def metadata
    render inline: SamlIdp.metadata.signed, content_type: 'text/xml'
  end

  def logout
    message = saml_logout_message

    return finish_slo_at_idp if message.nil? || message[:message].blank?

    sign_out current_user if message[:action] == 'sign out'

    render_template_for(
      Base64.strict_encode64(message[:message]),
      message[:action_url],
      message[:message_type]
    )
  end

  private

  def disable_caching
    expires_now
    response.headers['Pragma'] = 'no-cache'
  end

  def render_template_for(message, action_url, type)
    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: {
        action_url: action_url,
        message: message,
        type: type
      },
      layout: false
    )
  end

  def apply_secure_headers_override
    use_secure_headers_override(:saml)
  end
end
