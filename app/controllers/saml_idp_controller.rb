require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern
  include FullyAuthenticatable
  include VerifyProfileConcern
  include VerifySPAttributesConcern

  skip_before_action :verify_authenticity_token
  before_action :validate_saml_logout_request, only: :logout

  def auth
    return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
    link_identity_from_session_data
    capture_analytics
    return redirect_to_account_or_verify_profile_url if profile_or_identity_needs_verification?
    return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
    handle_successful_handoff
  end

  def metadata
    render inline: saml_metadata.signed, content_type: 'text/xml'
  end

  def logout
    prepare_saml_logout_response_and_request

    return handle_saml_logout_response if slo.successful_saml_response?
    return finish_slo_at_idp if slo.finish_logout_at_idp?
    return handle_saml_logout_request(name_id_user) if slo.valid_saml_request?

    generate_slo_request
  end

  private

  def validate_saml_logout_request(raw_saml_request = params[:SAMLRequest])
    request_valid = saml_request_valid?(raw_saml_request)

    track_logout_event(request_valid)
    return unless raw_saml_request

    head :bad_request unless request_valid
  end

  def saml_request_valid?(saml_request)
    return false unless saml_request
    decode_request(saml_request)
    valid_saml_request?
  end

  def saml_metadata
    if SamlCertRotationManager.use_new_secrets_for_request?(request)
      cert_rotation_saml_metadata
    else
      SamlIdp.metadata
    end
  end

  def cert_rotation_saml_metadata
    config = SamlIdp.config.dup
    suffix = SamlCertRotationManager.rotation_path_suffix
    config.single_service_post_location = config.single_service_post_location + suffix
    config.single_logout_service_post_location = config.single_logout_service_post_location + suffix
    SamlIdp::MetadataBuilder.new(
      config,
      SamlCertRotationManager.new_certificate,
      SamlCertRotationManager.new_secret_key
    )
  end

  def redirect_to_account_or_verify_profile_url
    return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
    redirect_to(verify_url) if identity_needs_verification?
  end

  def profile_or_identity_needs_verification?
    profile_needs_verification? || identity_needs_verification?
  end

  def capture_analytics
    analytics_payload = @result.to_h.merge(
      idv: identity_needs_verification?,
      finish_profile: profile_needs_verification?
    )
    analytics.track_event(Analytics::SAML_AUTH, analytics_payload)
  end

  def handle_successful_handoff
    delete_branded_experience
    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
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

  def track_logout_event(saml_request_valid)
    saml_request = params[:SAMLRequest]
    result = {
      sp_initiated: saml_request.present?,
      oidc: false,
    }
    result[:saml_request_valid] = saml_request_valid

    analytics.track_event(Analytics::LOGOUT_INITIATED, result)
  end
end
