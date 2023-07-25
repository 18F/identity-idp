module Users
  class PleaseCallController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.user_suspended_please_call_visited
    end
  end
end
