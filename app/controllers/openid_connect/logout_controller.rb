# frozen_string_literal: true

module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern
    include FullyAuthenticatable
    include OpenidConnectRedirectConcern

    before_action :set_devise_failure_redirect_for_concurrent_session_logout,
                  only: [:show, :create]
    before_action :confirm_two_factor_authenticated, only: [:delete]
    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :store_ui_locale

    # +GET+ Handle logout (with confirmation if initiated by relying partner)
    # @see {OpenID Connect RP-Initiated Logout 1.0 Specification}[https://openid.net/specs/openid-connect-rpinitiated-1_0.html#RPLogout]  # rubocop:disable Layout/LineLength
    def show
      @logout_form = build_logout_form
      result = @logout_form.submit
      redirect_uri = result.extra[:redirect_uri]
      analytics.oidc_logout_requested(
        **to_event(result),
        method: request.method.to_s,
        original_method: session[:original_method],
      )

      if result.success? && redirect_uri
        handle_successful_logout_request(result, redirect_uri)
      else
        track_integration_errors(result:, event: :oidc_logout_requested)

        render :error
      end
    end

    # +POST+ Handle logout request (with confirmation if initiated by relying partner)
    # @see {OpenID Connect RP-Initiated Logout 1.0 Specification}[https://openid.net/specs/openid-connect-rpinitiated-1_0.html#RPLogout] # rubocop:disable Layout/LineLength
    def create
      session[:original_method] = request.method.to_s
      redirect_to action: :show, **logout_params
    end

    # Sign out without confirmation
    def delete
      @logout_form = build_logout_form
      result = @logout_form.submit
      redirect_uri = result.extra[:redirect_uri]

      analytics.oidc_logout_submitted(**to_event(result))

      if result.success? && redirect_uri
        handle_logout(result, redirect_uri)
      else
        track_integration_errors(result:, event: :oidc_logout_submitted)

        render :error
      end
    end

    private

    def set_devise_failure_redirect_for_concurrent_session_logout
      request.env['devise_session_limited_failure_redirect_url'] = request.url
    end

    def redirect_user(redirect_uri, issuer, user_uuid)
      case oidc_redirect_method(issuer: issuer, user_uuid: user_uuid)
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

    def apply_logout_secure_headers_override(redirect_uri, service_provider)
      return if service_provider.nil? || redirect_uri.nil?
      return if form_action_csp_disabled_and_not_server_side_redirect?(
        issuer: service_provider.issuer,
        user_uuid: current_user&.id,
      )

      uris = SecureHeadersAllowList.csp_with_sp_redirect_uris(
        redirect_uri,
        service_provider.redirect_uris,
      )

      override_form_action_csp(uris)
    end

    def require_logout_confirmation?
      (logout_params[:id_token_hint].nil? || IdentityConfig.store.reject_id_token_hint_in_logout) &&
        logout_params[:client_id] &&
        current_user
    end

    # @return [OpenidConnectLogoutForm]
    def build_logout_form
      OpenidConnectLogoutForm.new(
        params: logout_params,
        current_user: current_user,
      )
    end

    # @param result [FormResponse] Response from submitting @logout_form
    # @param redirect_uri [String] The URL to redirect the user to after logout
    def handle_successful_logout_request(result, redirect_uri)
      apply_logout_secure_headers_override(redirect_uri, @logout_form.service_provider)
      if require_logout_confirmation?
        analytics.oidc_logout_visited(**to_event(result))

        @params = {
          client_id: logout_params[:client_id],
          post_logout_redirect_uri: logout_params[:post_logout_redirect_uri],
        }
        @params[:state] = logout_params[:state] if !logout_params[:state].nil?
        @service_provider_name = @logout_form.service_provider&.friendly_name
        delete_branded_experience(logout: true)

        render :confirm_logout
      else
        handle_logout(result, redirect_uri)
      end
    end

    def handle_logout(result, redirect_uri)
      analytics.logout_initiated(**to_event(result))

      redirect_user(redirect_uri, @logout_form.service_provider&.issuer, current_user&.uuid)

      sign_out
    end

    # Convert FormResponse into loggable analytics event
    # @param [FormResponse] result
    def to_event(result)
      result.to_h.except(:redirect_uri, :integration_errors)
    end

    def logout_params
      params.permit(:client_id, :id_token_hint, :post_logout_redirect_uri, :state)
    end

    def track_integration_errors(result:, event:)
      if result.extra[:integration_errors].present?
        analytics.sp_integration_errors_present(
          **result
            .to_h[:integration_errors]
            .merge(event:),
        )
      end
    end
  end
end
