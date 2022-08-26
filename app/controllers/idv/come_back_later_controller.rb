module Idv
  class ComeBackLaterController < ApplicationController
    include IdvStepConcern

    before_action :confirm_user_needs_gpo_confirmation

    def show
      analytics.idv_come_back_later_visit
      @step_indicator_steps = step_indicator_steps
    end

    private

    def confirm_user_needs_gpo_confirmation
      redirect_to account_url unless current_user.decorate.pending_profile_requires_verification?
    end
  end
end
