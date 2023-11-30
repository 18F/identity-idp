module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern
    include FullyAuthenticatable

    before_action :confirm_two_factor_authenticated, only: [:delete]

    def index
      @logout_form = build_logout_form

      result = @logout_form.submit
      analytics.oidc_logout_requested(**result.to_h.except(:redirect_uri))

      if result.success? && result.extra[:redirect_uri]
        handle_successful_logout_request(result, result.extra[:redirect_uri])
      else
        render :error
      end
    end

    def delete
      @logout_form = build_logout_form
      result = @logout_form.submit

      analytics.oidc_logout_submitted(**result.to_h.except(:redirect_uri))

      if result.success? && (redirect_uri = result.extra[:redirect_uri])
        analytics.logout_initiated(**result.to_h.except(:redirect_uri))
        irs_attempts_api_tracker.logout_initiated(success: result.success?)

        sign_out
        if IdentityConfig.store.openid_connect_redirect_interstitial_enabled
          @oidc_redirect_uri = redirect_uri
          render :redirect
        else
          redirect_to(
            redirect_uri,
            allow_other_host: true,
          )
        end
      else
        render :error
      end
    end

    private

    def apply_logout_secure_headers_override(redirect_uri, service_provider)
      return if service_provider.nil? || redirect_uri.nil?
      return if IdentityConfig.store.openid_connect_redirect_interstitial_enabled

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
        analytics.oidc_logout_visited(**result.to_h.except(:redirect_uri))
        @params = {
          client_id: logout_params[:client_id],
          post_logout_redirect_uri: logout_params[:post_logout_redirect_uri],
        }
        @params[:state] = logout_params[:state] if !logout_params[:state].nil?
        @service_provider_name = @logout_form.service_provider&.friendly_name
        delete_branded_experience(logout: true)

        render :index
      else
        analytics.logout_initiated(**result.to_h.except(:redirect_uri))
        irs_attempts_api_tracker.logout_initiated(success: result.success?)

        sign_out

        if IdentityConfig.store.openid_connect_redirect_interstitial_enabled
          @oidc_redirect_uri = redirect_uri
          render :redirect
        else
          redirect_to(
            redirect_uri,
            allow_other_host: true,
          )
        end
      end
    end

    def logout_params
      params.permit(:client_id, :id_token_hint, :post_logout_redirect_uri, :state)
    end
  end
end
