module OpenidConnect
  class LogoutController < ApplicationController
    include SecureHeadersConcern

    before_action :apply_secure_headers_override, only: [:index]

    def index
      @logout_form = OpenidConnectLogoutForm.new(
        params: logout_params,
        current_user: current_user,
      )

      result = @logout_form.submit

      analytics.logout_initiated(**result.to_h.except(:redirect_uri))
      irs_attempts_api_tracker.logout_initiated(
        success: result.success?,
      )

      if result.success? && (redirect_uri = result.extra[:redirect_uri])
        sign_out
        unless logout_params[:prevent_logout_redirect] == 'true'
          redirect_to(
            redirect_uri,
            allow_other_host: true,
          )
        end
      else
        render :error
      end
    end

    def logout_params
      permitted = [
        :id_token_hint,
        :post_logout_redirect_uri,
        :state,
        :prevent_logout_redirect,
      ]

      if IdentityConfig.store.accept_client_id_in_oidc_logout ||
         IdentityConfig.store.reject_id_token_hint_in_logout
        permitted << :client_id
      end
      params.permit(*permitted)
    end
  end
end
