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
    include SiteKeyConcern

    before_action :build_authorize_form_from_params, only: [:index]
    before_action :set_devise_failure_redirect_for_concurrent_session_logout
    before_action :pre_validate_authorize_form, only: [:index]
    before_action :sign_out_if_prompt_param_is_login_and_user_is_signed_in, only: [:index]
    before_action :store_request, only: [:index]
    before_action :start_delegation_context, only: [:index]
    before_action :check_sp_active, only: [:index]
    before_action :secure_headers_override, only: [:index]
    before_action :handle_banned_user
    before_action :handle_duplicate_profile_user, only: :index
    before_action :bump_auth_count, only: :index
    before_action :redirect_to_sign_in_or_create, only: :index, unless: :user_signed_in?
    before_action :confirm_two_factor_authenticated, only: :index
    before_action :redirect_to_reauthenticate, only: :index, if: :remember_device_expired_for_sp?
    before_action :prompt_for_password_if_ial2_request_and_pii_locked, only: [:index]
    before_action :confirm_user_is_not_suspended, only: :index
    before_action :confirm_password_change_not_required, only: :index
    before_action :confirm_site_key_available, only: :index

    def index
      if resolved_authn_context_result.identity_proofing?
        return redirect_to reactivate_account_url if user_needs_to_reactivate_account?
        return redirect_to url_for_pending_profile_reason if user_has_pending_profile?
        if identity_needs_verification? || facial_match_needed?
          return redirect_to idv_url
        end
        if needs_to_reproof?
          track_reproof_redirect
          return redirect_to idv_url
        end
      end
      return redirect_to sign_up_completed_url if needs_completion_screen_reason
      return redirect_user(site_key_error_redirect_uri) unless prepare_site_key
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

    def redirect_to_sign_in_or_create
      if @authorize_form.initiate_user_registration?
        redirect_to sign_up_email_url
      else
        redirect_to new_user_session_url
      end
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
      identity = current_user.identities.find_by(service_provider: sp_session[:issuer])
      return nil if !identity&.verified_single_email_attribute?
      if selected_email_id_for_linked_identity.present?
        return selected_email_id_for_linked_identity
      end

      identity&.email_address_id
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
      release_remembered_delegation
      redirect_uri = @authorize_form.success_redirect_uri
      redirect_uri = with_sealed_site_key(redirect_uri) if @authorize_form.site_key_requested?

      track_events
      sp_handoff_bouncer.add_handoff_time!

      # A site key in the fragment must never appear in a Location header or request log.
      redirect_user(redirect_uri, client_side: @authorize_form.site_key_requested?)

      sp_session[:successful_handoff] = true

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
      return if form_action_csp_disabled_and_not_server_side_redirect?

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
        redirect_user(redirect_uri)
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

    # Sends the user through the password prompt once per authorization request; if the root is
    # still not available after that, answers the SP with an error rather than prompting again.
    def confirm_site_key_available
      return unless @authorize_form.site_key_requested?

      case site_key_vault.status
      when :ready
        user_session.delete(:site_key_password_prompt)
      when :needs_recovery
        redirect_to site_key_recovery_url
      when :needs_acknowledgement
        redirect_to site_key_recovery_code_url
      else
        prompt_for_site_key_password
      end
    end

    def prompt_for_site_key_password
      if user_session.delete(:site_key_password_prompt) == site_key_request_digest
        redirect_user(site_key_error_redirect_uri)
      else
        remember_site_key_password_prompt
        redirect_to capture_password_url
      end
    end

    def remember_site_key_password_prompt
      return unless @authorize_form.site_key_requested?

      user_session[:site_key_password_prompt] = site_key_request_digest
    end

    def site_key_request_digest
      Digest::SHA256.hexdigest(
        [@authorize_form.client_id, @authorize_form.state, @authorize_form.site_key_jwk].join("\n"),
      )
    end

    # Seals the site key before the identity is linked, so a failure leaves no authorization
    # code or successful handoff behind.
    # @return [Boolean]
    def prepare_site_key
      return true unless @authorize_form.site_key_requested?

      URI(@authorize_form.redirect_uri)
      @site_key_emails = site_key_emails
      sealed = SiteKeys::Sealer.new(
        issuer: @authorize_form.client_id,
        recipient: SiteKeys::RecipientJwk.parse(@authorize_form.site_key_jwk),
      ).seal(key: site_key_vault.site_key(@authorize_form.client_id), **@site_key_emails)
      @site_key_fragment = URI.encode_www_form(site_key: sealed)
      true
    rescue SiteKeys::SealError, Encryption::EncryptionError, OpenSSL::OpenSSLError,
           URI::InvalidURIError => err
      analytics.site_key_release_failed(client_id: @authorize_form.client_id, error: err.message)
      false
    end

    def with_sealed_site_key(redirect_uri)
      analytics.site_key_released(
        client_id: @authorize_form.client_id,
        email_sealed: @site_key_emails[:email].present?,
        all_emails_sealed: @site_key_emails[:emails].present?,
      )
      uri = URI(redirect_uri)
      uri.fragment = @site_key_fragment
      uri.to_s
    end

    def site_key_error_redirect_uri
      UriService.add_params(
        @authorize_form.redirect_uri,
        error: 'temporarily_unavailable',
        error_description: t('openid_connect.authorization.errors.site_key_unavailable'),
        state: @authorize_form.state,
      )
    end

    # The addresses the userinfo endpoint would share for the `email` and `all_emails` scopes.
    def site_key_emails
      emails = {}
      if @authorize_form.scope.include?('all_emails')
        emails[:emails] = current_user.confirmed_email_addresses.map(&:email)
      end
      if @authorize_form.scope.include?('email')
        selected = current_user.email_addresses.find_by(id: email_address_id) if email_address_id
        emails[:email] = (selected || current_user.last_sign_in_email_address)&.email
      end
      emails
    end

    def prompt_for_password_if_ial2_request_and_pii_locked
      return unless pii_requested_but_locked?
      remember_site_key_password_prompt
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

    # When the validated request asks for delegation, note which agency recipients could receive
    # the session's fraud signals once the person approves. Only recipients enrolled in the
    # Attempts API are candidates; the events themselves are held in the session until then. This
    # runs before the person has signed in, so the sign-in's own events are captured.
    def start_delegation_context
      return unless DelegatedAccessEvents.enabled?

      scope_values = @authorize_form.requested_delegation_scopes
      return if scope_values.empty? || !service_provider&.delegation_service_provider?

      applications = DelegationApplications.requested(issuer, scope_values)
      # Each application's recipients are reached through its API URLs; load them in one query
      # when several applications are grouped so the lookup does not fan out per application.
      if applications.size > 1
        ActiveRecord::Associations::Preloader.new(
          records: applications,
          associations: { token_exchange_resource_servers: :attempts_service_provider },
        ).call
      end
      candidates = applications.flat_map(&:delegation_attempts_recipients).uniq
        .select(&:attempts_api_deliverable?)

      AttemptsApi::DelegationContext.from_session(session).start(
        request_id: sp_session[:request_id],
        sp_issuer: issuer,
        candidate_issuers: candidates.map(&:issuer),
      )
    end

    # When remembered approvals covered every requested application, the consent screen was
    # skipped and nothing has yet reached the agencies for this authorization: release now, before
    # `login-completed` is recorded, so that event reaches them too. A request the consent screen
    # already released is not released again.
    def release_remembered_delegation
      return unless DelegatedAccessEvents.enabled?

      scope_values = @authorize_form.requested_delegation_scopes
      return if scope_values.empty?
      return if AttemptsApi::DelegationContext.from_session(session)
        .released_for?(sp_session[:request_id])

      applications = DelegationApplications.requested(issuer, scope_values)
      # Each approval's currency is judged against its agency's material version; load the
      # agencies in one query rather than one per application.
      ActiveRecord::Associations::Preloader.new(records: applications, associations: :agency).call
      remembered = TokenExchangeGrant.live_by_application(
        user: current_user, service_provider_issuer: issuer, applications:,
      ).values.select(&:remembered_and_current?)
      return if remembered.empty?

      AttemptsApi::DelegatedRelease.new(
        user: current_user,
        session:,
        user_session:,
        analytics:,
        remembered_grants: remembered,
        request_id: sp_session[:request_id],
      ).call
    end

    def track_events
      analytics.sp_redirect_initiated(
        ial: ial_context.ial,
        billed_ial: ial_context.bill_for_ial_1_or_2,
        sign_in_flow: session[:sign_in_flow],
        acr_values: sp_session[:acr_values],
        sign_in_duration_seconds:,
      )

      attempts_api_tracker.login_completed
      track_billing_events
    end

    def redirect_user(redirect_uri, client_side: false)
      redirect = client_side ? 'client_side_js' : IdentityConfig.store.openid_connect_redirect
      case redirect
      when 'client_side_js'
        response.headers['Cache-Control'] = 'no-store' if client_side
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
      return nil if params[:acr_values].blank?

      (params[:acr_values].split - Saml::Idp::Constants::VALID_AUTHN_CONTEXTS)
        .join(' ').presence
    end

    def confirm_user_is_not_suspended
      redirect_to user_please_call_url if current_user.suspended?
    end

    def needs_to_reproof?
      reproofing_policy.needs_to_reproof?
    end

    def track_reproof_redirect
      analytics.idv_reproof_needed(
        reproof_reason: reproofing_policy.reproof_reason,
        initiating_sp_issuer: current_user.active_profile&.initiating_service_provider_issuer,
        previous_idv_level: current_user.active_profile&.idv_level,
      )
    end

    def reproofing_policy
      @reproofing_policy ||= Idv::ServiceProviderBasedReproofingPolicy.new(
        active_profile: current_user.active_profile,
        service_provider: current_sp,
        resolved_authn_context_result: resolved_authn_context_result,
      )
    end
  end
end
