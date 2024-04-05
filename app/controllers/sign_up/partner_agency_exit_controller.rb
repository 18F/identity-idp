# frozen_string_literal: true

module SignUp
  class PartnerAgencyExitController < Redirect::ReturnToSpController
    before_action :confirm_user_authenticated_for_2fa_setup

    def show
      binding.pry
      redirect_url = sp_return_url_resolver.return_to_sp_url
      analytics.return_to_sp_cancelled(redirect_url: redirect_url, **location_params)
    end

    private

    def sp_return_url_resolver
      @sp_return_url_resolver ||= SpReturnUrlResolver.new(
        service_provider: current_sp,
        oidc_state: sp_request_params[:state],
        oidc_redirect_uri: sp_request_params[:redirect_uri],
      )
    end
  end
end
