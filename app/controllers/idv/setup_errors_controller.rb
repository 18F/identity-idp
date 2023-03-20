module Idv
  class SetupErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.idv_setup_errors_visited

      @call_by_date = current_user.profiles.last.verified_at + 14.days
    end
  end
end
