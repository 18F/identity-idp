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
  include AuthorizationCountConcern
  include BillableEventTrackable

  prepend_before_action :skip_session_load, only: :metadata
  prepend_before_action :skip_session_expiration, only: :metadata

  skip_before_action :verify_authenticity_token
  before_action :confirm_user_is_authenticated_with_fresh_mfa, only: :auth
  before_action :bump_auth_count, only: [:auth]

  def auth
    capture_analytics
    return redirect_to_verification_url if profile_or_identity_needs_verification_or_decryption?
    return redirect_to(sign_up_completed_url) if needs_sp_attribute_verification?
    if auth_count == 1 && first_visit_for_sp?
      return redirect_to(user_authorization_confirmation_url)
    end
    link_identity_from_session_data
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
    bump_auth_count unless user_fully_authenticated?
    return confirm_two_factor_authenticated(request_id) unless user_fully_authenticated? &&
                                                               service_provider_mfa_policy.
                                                               auth_method_confirms_to_sp_request?
    redirect_to user_two_factor_authentication_url if remember_device_expired_for_sp?
  end

  def saml_metadata
    SamlEndpoint.new(request).saml_metadata
  end

  def redirect_to_verification_url
    return redirect_to(account_or_verify_profile_url) if profile_needs_verification?
    redirect_to(idv_url) if identity_needs_verification?
    redirect_to capture_password_url if identity_needs_decryption?
  end

  def profile_or_identity_needs_verification_or_decryption?
    return false unless ial2_requested?
    profile_needs_verification? || identity_needs_verification? || identity_needs_decryption?
  end

  def identity_needs_decryption?
    UserDecorator.new(current_user).identity_verified? && user_session[:decrypted_pii].blank?
  end

  def capture_analytics
    analytics_payload = @result.to_h.merge(
      endpoint: remap_auth_post_path(request.env['PATH_INFO']),
      idv: identity_needs_verification?,
      finish_profile: profile_needs_verification?,
    )
    analytics.track_event(Analytics::SAML_AUTH, analytics_payload)
  end

  def handle_successful_handoff
    track_events
    delete_branded_experience
    return redirect_to(account_url) if saml_request.response_url.blank?
    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
  end

  def render_template_for(message, action_url, type)
    domain = SecureHeadersAllowList.extract_domain(action_url)

    # Returns fully formed CSP array w/"'self'", domain, and ServiceProvider#redirect_uris
    csp_uris = SecureHeadersAllowList.csp_with_sp_redirect_uris(
      domain, decorated_session.sp_redirect_uris
    )
    override_content_security_policy_directives(form_action: csp_uris)

    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: { action_url: action_url, message: message, type: type, csp_uris: csp_uris },
      layout: false,
    )
  end

  def track_events
    analytics.track_event(Analytics::SP_REDIRECT_INITIATED, ial: sp_session_ial)
    track_billing_events
  end
end
