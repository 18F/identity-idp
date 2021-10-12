module Users
  class ForgetAllBrowsersController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.track_event(Analytics::FORGET_ALL_BROWSERS_VISITED)
    end

    def destroy
      ForgetAllBrowsers.new(current_user).call

      analytics.track_event(Analytics::FORGET_ALL_BROWSERS_SUBMITTED)

      redirect_to account_path
    end
  end
end
