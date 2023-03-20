module Idv
  class VerifyErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      #analytics.idv_verify_errors_visited 
    end
  end
end
