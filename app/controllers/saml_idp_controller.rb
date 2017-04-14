require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern
  include FullyAuthenticatable

  skip_before_action :verify_authenticity_token
  skip_before_action :handle_two_factor_authentication, only: :logout

  def auth
    return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
    process_fully_authenticated_user do |needs_idv|
      return store_location_and_redirect_to_verify_url if needs_idv
    end
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

  def process_fully_authenticated_user
    link_identity_from_session_data

    needs_idv = identity_needs_verification?
    analytics.track_event(Analytics::SAML_AUTH, @result.to_h.merge(idv: needs_idv))

    yield needs_idv
  end

  def store_location_and_redirect_to_verify_url
    store_location_for(:user, request.original_url)
    redirect_to verify_url
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
end
