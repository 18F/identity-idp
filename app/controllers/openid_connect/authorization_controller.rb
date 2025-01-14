# frozen_string_literal: true

module OpenidConnect
  class AuthorizationController < ApplicationController
    include FullyAuthenticatable
    include RememberDeviceConcern
    include VerifyProfileConcern
    include SecureHeadersConcern
    include AuthorizationCountConcern
    include BillableEventTrackable
    include ForcedReauthenticationConcern
    include OpenidConnectRedirectConcern
    include SignInDurationConcern

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :set_devise_failure_redirect_for_concurrent_session_logout
    before_action :pre_validate_authorize_form, only: [:index]
    before_action :sign_out_if_prompt_param_is_login_and_user_is_signed_in, only: [:index]
    before_action :store_request, only: [:index]
    before_action :check_sp_active, only: [:index]
    before_action :secure_headers_override, only: [:index]
    before_action :handle_banned_user
    before_action :bump_auth_count, only: :index
    before_action :redirect_to_sign_in, only: :index, unless: :user_signed_in?
    before_action :confirm_two_factor_authenticated, only: :index
    before_action :redirect_to_reauthenticate, only: :index, if: :remember_device_expired_for_sp?
    before_action :prompt_for_password_if_ial2_request_and_pii_locked, only: [:index]

    def index
      if resolved_authn_context_result.identity_proofing?
        return redirect_to reactivate_account_url if user_needs_to_reactivate_account?
        return redirect_to url_for_pending_profile_reason if user_has_pending_profile?
        return redirect_to idv_url if identity_needs_verification?
        return redirect_to idv_url if facial_match_needed?
      end
      return redirect_to sign_up_completed_url if needs_completion_screen_reason
      link_identity_to_service_provider

      result = @authorize_form.submit

      if auth_count == 1 && first_visit_for_sp?
        track_handoff_analytics(result, user_sp_authorized: false)
        return redirect_to(user_authorization_confirmation_url)
      end
      track_handoff_analytics(result, user_sp_authorized: true)
      handle_successful_handoff
    end

    private

    def pending_profile_policy
      @pending_profile_policy ||= PendingProfilePolicy.new(
        user: current_user,
        resolved_authn_context_result: resolved_authn_context_result,
      )
    end

    def check_sp_active
      return if service_provider&.active?
      redirect_to sp_inactive_error_url
    end

    def check_sp_handoff_bounced
      return unless sp_handoff_bouncer.bounced?
      analytics.sp_handoff_bounced_detected
      redirect_to bounced_url
      true
    end

    def redirect_to_sign_in
      redirect_to new_user_session_url
    end

    def redirect_to_reauthenticate
      redirect_to user_two_factor_authentication_url
    end

    def set_devise_failure_redirect_for_concurrent_session_logout
      request.env['devise_session_limited_failure_redirect_url'] = request.url
    end

    def link_identity_to_service_provider
      @authorize_form.link_identity_to_service_provider(
        current_user: current_user,
        ial: resolved_authn_context_int_ial,
        rails_session_id: session.id,
        email_address_id: email_address_id,
      )
    end

    def email_address_id
      return nil unless IdentityConfig.store.feature_select_email_to_share_enabled &&
                        if user_session[:selected_email_id_for_linked_identity].present?
                          return user_session[:selected_email_id_for_linked_identity]
                        end
      identity = current_user.identities.find_by(service_provider: sp_session[:issuer])
      identity&.email_address_for_sharing&.id
    end

    def ial_context
      IalContext.new(
        ial: resolved_authn_context_int_ial,
        service_provider:,
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

    def handle_successful_handoff
      track_events
      sp_handoff_bouncer.add_handoff_time!

      redirect_user(
        @authorize_form.success_redirect_uri,
        current_user.uuid,
      )

      delete_branded_experience
    end

    def track_handoff_analytics(result, attributes = {})
      analytics.openid_connect_authorization_handoff(
        **attributes.merge(result.to_h.slice(:client_id, :code_digest)).merge(
          success: result.success?,
        ),
      )
    end

    def identity_needs_verification?
      resolved_authn_context_result.identity_proofing? &&
        (current_user.identity_not_verified? ||
        decorated_sp_session.requested_more_recent_verification?)
    end

    def facial_match_needed?
      resolved_authn_context_result.facial_match? &&
        !current_user.identity_verified_with_facial_match?
    end

    def build_authorize_form_from_params
      @authorize_form = OpenidConnectAuthorizeForm.new(authorization_params)
    end

    def secure_headers_override
      return if form_action_csp_disabled_and_not_server_side_redirect?(
        issuer: issuer,
        user_uuid: current_user&.uuid,
      )

      csp_uris = SecureHeadersAllowList.csp_with_sp_redirect_uris(
        @authorize_form.redirect_uri,
        service_provider.redirect_uris,
      )
      override_form_action_csp(csp_uris)
    end

    def authorization_params
      params.permit(OpenidConnectAuthorizeForm::ATTRS)
    end

    def pre_validate_authorize_form
      result = @authorize_form.submit

      analytics.openid_connect_request_authorization(
        **result.to_h.except(:redirect_uri, :code_digest, :integration_errors).merge(
          user_fully_authenticated: user_fully_authenticated?,
          referer: request.referer,
          vtr_param: params[:vtr],
          unknown_authn_contexts:,
        ),
      )
      return if result.success?

      if result.extra[:integration_errors].present?
        analytics.sp_integration_errors_present(
          **result.to_h[:integration_errors],
        )
      end

      redirect_uri = result.extra[:redirect_uri]

      if redirect_uri.nil?
        render :error
      else
        redirect_user(redirect_uri, current_user&.uuid)
      end
    end

    def sign_out_if_prompt_param_is_login_and_user_is_signed_in
      if @authorize_form.prompt != 'login'
        set_issuer_forced_reauthentication(
          issuer:,
          is_forced_reauthentication: false,
        )
      end
      return unless @authorize_form.prompt == 'login'
      return if session[:oidc_state_for_login_prompt] == @authorize_form.state
      session[:oidc_state_for_login_prompt] = @authorize_form.state
      return unless user_signed_in?
      return if check_sp_handoff_bounced
      unless sp_session[:request_url] == request.original_url
        sign_out
        set_issuer_forced_reauthentication(
          issuer:,
          is_forced_reauthentication: true,
        )
      end
    end

    def prompt_for_password_if_ial2_request_and_pii_locked
      return unless pii_requested_but_locked?
      redirect_to capture_password_url
    end

    def store_request
      ServiceProviderRequestHandler.new(
        url: request.original_url,
        session: session,
        protocol_request: @authorize_form,
        protocol: FederatedProtocols::Oidc,
      ).call
    end

    def track_events
      analytics.sp_redirect_initiated(
        ial: ial_context.ial,
        billed_ial: ial_context.bill_for_ial_1_or_2,
        sign_in_flow: session[:sign_in_flow],
        vtr: sp_session[:vtr],
        acr_values: sp_session[:acr_values],
        sign_in_duration_seconds:,
      )
      track_billing_events
    end

    def redirect_user(redirect_uri, user_uuid)
      case oidc_redirect_method(issuer:, user_uuid: user_uuid)
      when 'client_side'
        @oidc_redirect_uri = redirect_uri
        render(
          'openid_connect/shared/redirect',
          layout: false,
        )
      when 'client_side_js'
        @oidc_redirect_uri = redirect_uri
        render(
          'openid_connect/shared/redirect_js',
          layout: false,
        )
      else # should only be :server_side
        redirect_to(
          redirect_uri,
          allow_other_host: true,
        )
      end
    end

    def service_provider
      @authorize_form.service_provider
    end

    def issuer
      service_provider&.issuer
    end

    def sp_handoff_bouncer
      @sp_handoff_bouncer ||= SpHandoffBouncer.new(sp_session)
    end

    def unknown_authn_contexts
      return nil if params[:vtr].present? || params[:acr_values].blank?

      (params[:acr_values].split - Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
        .join(' ').presence
    end
  end
end
