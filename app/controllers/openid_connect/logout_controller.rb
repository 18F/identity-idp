module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern
    include RenderConditionConcern

    check_or_render_not_found -> do
      IdentityConfig.store.accept_client_id_in_oidc_logout ||
        IdentityConfig.store.reject_id_token_hint_in_logout
    end, only: [:delete]

    before_action :apply_secure_headers_override, only: [:index, :delete]
    before_action :confirm_two_factor_authenticated, only: [:delete]

    def index
      @logout_form = build_logout_form

      result = @logout_form.submit

      analytics.logout_initiated(**result.to_h.except(:redirect_uri))
      irs_attempts_api_tracker.logout_initiated(
        success: result.success?,
      )

      if result.success? && (redirect_uri = result.extra[:redirect_uri])
        handle_successful_logout_request(redirect_uri)
      else
        render :error
      end
    end

    def delete
      @logout_form = build_logout_form
      result = @logout_form.submit
      if result.success? && (redirect_uri = result.extra[:redirect_uri])
        sign_out
        redirect_to(
          redirect_uri,
          allow_other_host: true,
        )
      else
        render :error
      end
    end

    private

    def build_logout_form
      OpenidConnectLogoutForm.new(
        params: logout_params,
        current_user: current_user,
      )
    end

    def handle_successful_logout_request(redirect_uri)
      if logout_params[:client_id] && logout_params[:id_token_hint].nil? && current_user
        @client_id = logout_params[:client_id]
        @state = logout_params[:state]
        @post_logout_redirect_uri = logout_params[:post_logout_redirect_uri]
        render :index
      else
        sign_out
        redirect_to(
          redirect_uri,
          allow_other_host: true,
        )
      end
    end

    def logout_params
      permitted = [
        :id_token_hint,
        :post_logout_redirect_uri,
        :state,
      ]

      if IdentityConfig.store.accept_client_id_in_oidc_logout ||
         IdentityConfig.store.reject_id_token_hint_in_logout
        permitted << :client_id
      end
      params.permit(*permitted)
    end
  end
end
