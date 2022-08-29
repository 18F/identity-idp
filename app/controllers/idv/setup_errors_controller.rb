module Idv
  class SetupErrorsController < ApplicationController
    before_action :confirm_two_factor_authenticated
    def show
    end
  end
end
