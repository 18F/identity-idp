module Verify
  class ComeBackLaterController < ApplicationController
    include IdvSession

    before_action :confirm_idv_session_completed
    before_action :confirm_usps_verification_method_chosen

    def show; end

    private

    def confirm_idv_session_completed
      redirect_to account_path if idv_session.profile.blank?
    end

    def confirm_usps_verification_method_chosen
      redirect_to account_path unless idv_session.address_verification_mechanism == 'usps'
    end
  end
end
