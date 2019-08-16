require 'saml_idp_constants'
require 'saml_idp'
require 'uuid'

class SamlIdpController < ApplicationController
  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern
  include FullyAuthenticatable
  include RememberDeviceConcern
  include VerifyProfileConcern

  skip_before_action :verify_authenticity_token
  before_action :confirm_user_is_authenticated_with_fresh_mfa, only: :auth

  def auth
    link_identity_from_session_data
    capture_analytics
    return redirect_to two_factor_options_url unless
      MfaPolicy.new(current_user).sufficient_factors_enabled?
    return redirect_to_account_or_verify_profile_url if profile_or_identity_needs_verification?
    return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
    handle_successful_handoff
  end

  def metadata
    render inline: saml_metadata.signed, content_type: 'text/xml'
  end

  def logout
    raw_saml_request = params[:SAMLRequest]
    return sign_out_with_flash if raw_saml_request.nil?

    decode_request(raw_saml_request)
    track_logout_event

    return head(:bad_request) unless valid_saml_request?

    handle_valid_sp_logout_request
  end

  private

  def confirm_user_is_authenticated_with_fresh_mfa
    return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated?
    redirect_to user_two_factor_authentication_url if remember_device_expired_for_sp?
  end

  def saml_request_valid?(saml_request)
    return false unless saml_request
    decode_request(saml_request)
    valid_saml_request?
  end

  def saml_metadata
    SamlEndpoint.new(request).saml_metadata
  end

  def redirect_to_account_or_verify_profile_url
    return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
    redirect_to(idv_url) if identity_needs_verification?
  end

  def profile_or_identity_needs_verification?
    return false unless loa3_requested?
    profile_needs_verification? || identity_needs_verification?
  end

  def capture_analytics
    analytics_payload = @result.to_h.merge(
      idv: identity_needs_verification?,
      finish_profile: profile_needs_verification?,
    )
    analytics.track_event(Analytics::SAML_AUTH, analytics_payload)
  end

  def handle_successful_handoff
    analytics.track_event(Analytics::SP_REDIRECT_INITIATED)
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
      layout: false,
    )
  end
end
