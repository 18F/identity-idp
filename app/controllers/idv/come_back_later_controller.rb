module Idv
  class ComeBackLaterController < ApplicationController
    before_action :confirm_two_factor_authenticated
    before_action :confirm_user_needs_usps_confirmation

    def show
      analytics.track_event(Analytics::IDV_COME_BACK_LATER_VISIT)
    end

    private

    def confirm_user_needs_usps_confirmation
      redirect_to account_url unless current_user.decorate.pending_profile_requires_verification?
    end
  end
end
