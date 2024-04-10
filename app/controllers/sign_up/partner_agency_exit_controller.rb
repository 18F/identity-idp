# frozen_string_literal: true

module SignUp
  class PartnerAgencyExitController < Redirect::ReturnToSpController
    before_action :confirm_user_authenticated_for_2fa_setup

    def show
      @return_to_sp_url = sp_return_url_resolver.return_to_sp_url
    end
  end
end
