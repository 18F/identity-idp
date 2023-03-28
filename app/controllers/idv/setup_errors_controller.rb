module Idv
  class SetupErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      analytics.idv_setup_errors_visited
    end
  end
end
