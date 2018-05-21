module Idv
  class ComeBackLaterController < ApplicationController
    include IdvSession

    before_action :confirm_user_needs_usps_confirmation

    def show; end

    private

    def confirm_user_needs_usps_confirmation
      redirect_to account_url unless current_user.decorate.needs_profile_usps_verification?
    end
  end
end
