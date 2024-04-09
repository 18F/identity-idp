# frozen_string_literal: true

module SignUp
  class PartnerAgencyExitController < Redirect::ReturnToSpController
    before_action :confirm_user_authenticated_for_2fa_setup

    def show
      redirect_url = sp_return_url_resolver.return_to_sp_url
      @presenter = ReturnToSpPresenter.new(return_to_sp_url: redirect_url)
      analytics.return_to_sp_cancelled(redirect_url: redirect_url, **location_params)
    end
  end
end
