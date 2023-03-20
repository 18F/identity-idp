module Idv
  class OutageController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated

    def show
      session[:skip_vendor_outage] = true
      render :show, locals: { current_sp: current_sp }
    end
  end
end
