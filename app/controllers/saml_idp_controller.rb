require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern
  include FullyAuthenticatable
  include VerifyProfileConcern

  skip_before_action :verify_authenticity_token

  def auth
    return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
    process_fully_authenticated_user do |needs_idv, needs_profile_finish|
      return redirect_to(verify_url) if needs_idv && !needs_profile_finish
      return redirect_to(account_or_verify_profile_url) if needs_profile_finish
    end
    delete_branded_experience

    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
  end

  def metadata
    render inline: saml_metadata.signed, content_type: 'text/xml'
  end

  def logout
    track_logout_event
    prepare_saml_logout_response_and_request

    return handle_saml_logout_response if slo.successful_saml_response?
    return finish_slo_at_idp if slo.finish_logout_at_idp?
    return handle_saml_logout_request(name_id_user) if slo.valid_saml_request?

    generate_slo_request
  end

  private

  def saml_metadata
    if SamlCertRotationManager.use_new_secrets_for_request?(request)
      SamlIdp::MetadataBuilder.new(
        SamlIdp.config,
        SamlCertRotationManager.new_certificate,
        SamlCertRotationManager.new_secret_key
      )
    else
      SamlIdp.metadata
    end
  end

  def process_fully_authenticated_user
    link_identity_from_session_data

    needs_idv = identity_needs_verification?
    needs_profile_finish = profile_needs_verification?
    analytics_payload =  @result.to_h.merge(idv: needs_idv, finish_profile: needs_profile_finish)
    analytics.track_event(Analytics::SAML_AUTH, analytics_payload)

    yield needs_idv, needs_profile_finish
  end

  def render_template_for(message, action_url, type)
    domain = SecureHeadersWhitelister.extract_domain(action_url)

    # Returns fully formed CSP array w/"'self'", domain, and ServiceProvider#redirect_uris
    csp_uris = SecureHeadersWhitelister.csp_with_sp_redirect_uris(
      domain, decorated_session.sp_redirect_uris
    )
    override_content_security_policy_directives(form_action: csp_uris)

    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: { action_url: action_url, message: message, type: type },
      layout: false
    )
  end

  def track_logout_event
    result = {
      sp_initiated: params[:SAMLRequest].present?,
      oidc: false,
    }
    analytics.track_event(Analytics::LOGOUT_INITIATED, result)
  end
end
