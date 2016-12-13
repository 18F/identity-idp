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

    needs_idv = identity_needs_verification?
    analytics.track_event(Analytics::SAML_AUTH, @result.merge(idv: needs_idv))

    return redirect_to verify_url if needs_idv

    delete_branded_experience
    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
  end

  def metadata
    render inline: SamlIdp.metadata.signed, content_type: 'text/xml'
  end

  def logout
    prepare_saml_logout_response_and_request

    return handle_saml_logout_response if slo.successful_saml_response?
    return finish_slo_at_idp if slo.finish_logout_at_idp?
    return handle_saml_logout_request(name_id_user) if slo.valid_saml_request?

    generate_slo_request
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

  def delete_branded_experience
    session.delete(:sp) if session[:sp]
  end
end
