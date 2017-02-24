require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern

  skip_before_action :verify_authenticity_token

  before_action :disable_caching

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
    domain = SecureHeadersWhitelister.extract_domain(action_url)
    override_content_security_policy_directives(form_action: ["'self'", domain])

    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: { action_url: action_url, message: message, type: type },
      layout: false
    )
  end

  def delete_branded_experience
    session.delete(:sp)
    session.delete('user_return_to')
  end
end
