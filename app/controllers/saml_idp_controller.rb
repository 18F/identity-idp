# frozen_string_literal: true

require 'saml_idp_constants'
require 'saml_idp'

class SamlIdpController < ApplicationController
  # Ordering is significant, since failure URL must be assigned before any references to the user,
  # as the concurrent session timeout occurs as a callback to Warden's `after_set_user` hook.
  before_action :set_devise_failure_redirect_for_concurrent_session_logout, only: [:auth, :logout]

  include SamlIdp::Controller
  include SamlIdpAuthConcern
  include SamlIdpLogoutConcern
  include FullyAuthenticatable
  include RememberDeviceConcern
  include VerifyProfileConcern
  include AuthorizationCountConcern
  include BillableEventTrackable
  include SecureHeadersConcern
  include SignInDurationConcern

  prepend_before_action :skip_session_load, only: [:metadata, :remotelogout]
  prepend_before_action :skip_session_expiration, only: [:metadata, :remotelogout]

  skip_before_action :verify_authenticity_token
  before_action :require_path_year
  before_action :handle_banned_user
  before_action :bump_auth_count, only: :auth
  before_action :redirect_to_sign_in, only: :auth, unless: :user_signed_in?
  before_action :confirm_two_factor_authenticated, only: :auth
  before_action :redirect_to_reauthenticate, only: :auth, if: :remember_device_expired_for_sp?
  before_action :prompt_for_password_if_ial2_request_and_pii_locked, only: :auth

  def auth
    capture_analytics
    if resolved_authn_context_result.identity_proofing?
      return redirect_to reactivate_account_url if user_needs_to_reactivate_account?
      return redirect_to url_for_pending_profile_reason if user_has_pending_profile?
      return redirect_to idv_url if identity_needs_verification?
      return redirect_to idv_url if facial_match_needed?
    end
    return redirect_to sign_up_completed_url if needs_completion_screen_reason
    if auth_count == 1 && first_visit_for_sp?
      return redirect_to(user_authorization_confirmation_url)
    end
    link_identity_from_session_data
    handle_successful_handoff
  end

  def metadata
    # rubocop:disable Rails/RenderInline
    render inline: saml_metadata.signed, content_type: 'text/xml'
    # rubocop:enable Rails/RenderInline
  end

  def logout
    raw_saml_request = params[:SAMLRequest]
    return sign_out_with_flash if raw_saml_request.nil?

    decode_request(raw_saml_request)

    track_logout_event

    unless valid_saml_request?
      track_integration_errors(event: :saml_logout_request)

      return head(:bad_request)
    end

    handle_valid_sp_logout_request
  end

  def remotelogout
    raw_saml_request = params[:SAMLRequest]
    return head(:bad_request) if raw_saml_request.nil?

    decode_request(raw_saml_request)
    issuer = saml_request&.issuer

    track_remote_logout_event(issuer)

    unless valid_saml_request?
      track_integration_errors(event: :saml_remote_logout_request)

      return head(:bad_request)
    end

    user_id = find_user_from_session_index

    unless user_id.present?
      track_integration_errors(
        event: :saml_remote_logout_request,
        errors: [:no_user_found_from_session_index],
      )
      return head(:bad_request)
    end

    handle_valid_sp_remote_logout_request(user_id: user_id, issuer: issuer)
  end

  def external_saml_request?
    return true if request.path.start_with?('/api/saml/authpost')

    begin
      URI(request.referer).host != request.host
    rescue ArgumentError, URI::Error
      false
    end
  end

  private

  def redirect_to_sign_in
    redirect_to new_user_session_url
  end

  def redirect_to_reauthenticate
    redirect_to user_two_factor_authentication_url
  end

  def saml_metadata
    SamlEndpoint.new(params[:path_year]).saml_metadata
  end

  def prompt_for_password_if_ial2_request_and_pii_locked
    return unless pii_requested_but_locked?
    redirect_to capture_password_url
  end

  def facial_match_needed?
    resolved_authn_context_result.facial_match? &&
      !current_user.identity_verified_with_facial_match?
  end

  def set_devise_failure_redirect_for_concurrent_session_logout
    request.env['devise_session_limited_failure_redirect_url'] = request.url
  end

  def capture_analytics
    analytics_payload = result.to_h.merge(
      endpoint: api_saml_auth_path(path_year: params[:path_year]),
      idv: identity_needs_verification?,
      finish_profile: user_has_pending_profile?,
      requested_ial: requested_ial,
      request_signed: saml_request.signed?,
      matching_cert_serial:,
      requested_nameid_format: saml_request.name_id_format,
      unknown_authn_contexts:,
    )

    if result.success? && saml_request.signed?
      analytics_payload[:cert_error_details] = saml_request.cert_errors
    end

    analytics.saml_auth(**analytics_payload)
  end

  def matching_cert_serial
    saml_request.matching_cert&.serial&.to_s
  rescue SamlIdp::XMLSecurity::SignedDocument::ValidationError
    nil
  end

  def log_external_saml_auth_request
    return unless external_saml_request?

    analytics.saml_auth_request(
      requested_ial: requested_ial,
      authn_context: requested_authn_contexts,
      requested_aal_authn_context: FederatedProtocols::Saml.new(saml_request).aal,
      requested_vtr_authn_contexts: saml_request&.requested_vtr_authn_contexts.presence,
      force_authn: saml_request&.force_authn?,
      final_auth_request: sp_session[:final_auth_request],
      service_provider: saml_request&.issuer,
      request_signed: saml_request.signed?,
      matching_cert_serial:,
      unknown_authn_contexts:,
      user_fully_authenticated: user_fully_authenticated?,
    )
  end

  def requested_ial
    saml_protocol = FederatedProtocols::Saml.new(saml_request)
    requested_ial_acr = saml_protocol.ial
    if requested_ial_acr == ::Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
      return 'ialmax'
    else
      saml_protocol.requested_ial_authn_context.presence || 'none'
    end
  end

  def handle_successful_handoff
    track_events
    delete_branded_experience
    return redirect_to(account_url) if saml_request.response_url.blank?
    render_template_for(saml_response, saml_request.response_url, 'SAMLResponse')
  end

  def render_template_for(message, action_url, type)
    # Returns fully formed CSP array w/"'self'", domain, and ServiceProvider#redirect_uris
    redirect_uris = decorated_sp_session.sp_redirect_uris ||
                    sp_from_request_issuer_logout&.redirect_uris.to_a.compact
    csp_uris = SecureHeadersAllowList.csp_with_sp_redirect_uris(
      action_url, redirect_uris
    )
    override_form_action_csp(csp_uris)

    render(
      template: 'saml_idp/shared/saml_post_binding',
      locals: { action_url: action_url, message: message, type: type, csp_uris: csp_uris },
      layout: false,
    )
  end

  def track_events
    analytics.sp_redirect_initiated(
      ial: resolved_authn_context_int_ial,
      billed_ial: ial_context.bill_for_ial_1_or_2,
      sign_in_flow: session[:sign_in_flow],
      vtr: sp_session[:vtr],
      acr_values: sp_session[:acr_values],
      sign_in_duration_seconds:,
    )
    track_billing_events
  end

  def ial_context
    @ial_context ||= IalContext.new(
      ial: resolved_authn_context_int_ial,
      service_provider: saml_request_service_provider,
      user: current_user,
    )
  end

  def resolved_authn_context_int_ial
    if resolved_authn_context_result.ialmax?
      0
    elsif resolved_authn_context_result.identity_proofing?
      2
    else
      1
    end
  end

  def require_path_year
    render_not_found if params[:path_year].blank?
  end

  def unknown_authn_contexts
    return nil if saml_request.requested_vtr_authn_contexts.present?
    return nil if requested_authn_contexts.blank?

    unmatched_authn_contexts.reject do |authn_context|
      authn_context.match(req_attrs_regexp)
    end.join(' ').presence
  end

  def unmatched_authn_contexts
    requested_authn_contexts - Saml::Idp::Constants::VALID_AUTHN_CONTEXTS
  end

  def requested_authn_contexts
    @request_authn_contexts || saml_request&.requested_authn_contexts
  end

  def req_attrs_regexp
    Regexp.escape(Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF)
  end
end
