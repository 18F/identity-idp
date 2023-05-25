module Idv
  class ComeBackLaterController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_needs_gpo_confirmation

    def show
      analytics.idv_come_back_later_visit
    end

    private

    def confirm_user_needs_gpo_confirmation
      redirect_to account_url unless current_user.gpo_verification_pending_profile?
    end
  end
end
