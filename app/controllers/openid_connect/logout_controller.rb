# frozen_string_literal: true

module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern
    include FullyAuthenticatable

    before_action :set_devise_failure_redirect_for_concurrent_session_logout,
                  only: [:logout]
    before_action :confirm_two_factor_authenticated, only: [:delete]

    # Handle logout (with confirmation if initiated by relying partner)
    def logout
      @logout_form = build_logout_form
      result = @logout_form.submit
      redirect_uri = result.extra[:redirect_uri]

      analytics.oidc_logout_requested(**to_event(result))

      if result.success? && redirect_uri
        handle_successful_logout_request(result, redirect_uri)
      else
        render :error
      end
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
        render :error
      end
    end

    private

    def set_devise_failure_redirect_for_concurrent_session_logout
      request.env['devise_session_limited_failure_redirect_url'] = request.url
    end

    def redirect_user(redirect_uri, issuer, user_uuid)
      user_redirect_method_override =
        IdentityConfig.store.openid_connect_redirect_uuid_override_map[user_uuid]

      sp_redirect_method_override =
        IdentityConfig.store.openid_connect_redirect_issuer_override_map[issuer]

      redirect_method =
        user_redirect_method_override || sp_redirect_method_override ||
        IdentityConfig.store.openid_connect_redirect

      case redirect_method
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
      return unless IdentityConfig.store.openid_connect_content_security_form_action_enabled

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

    def build_logout_form
      OpenidConnectLogoutForm.new(
        params: logout_params,
        current_user: current_user,
      )
    end

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
      irs_attempts_api_tracker.logout_initiated(success: result.success?)

      sign_out

      redirect_user(redirect_uri, @logout_form.service_provider&.issuer, current_user&.uuid)
    end

    # Convert FormResponse into loggable analytics event
    # @param [FormResponse] result
    def to_event(result)
      result.to_h.except(:redirect_uri)
    end

    def logout_params
      params.permit(:client_id, :id_token_hint, :post_logout_redirect_uri, :state)
    end
  end
end
