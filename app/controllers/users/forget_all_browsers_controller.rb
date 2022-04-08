module Users
  class ForgetAllBrowsersController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.forget_all_browsers_visited
    end

    def destroy
      ForgetAllBrowsers.new(current_user).call

      analytics.forget_all_browsers_submitted

      redirect_to account_path
    end
  end
end
