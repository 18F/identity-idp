module Idv
  class ReproofingStartedController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def new; end
  end
end
