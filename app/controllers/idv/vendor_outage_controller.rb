module Idv
  class VendorOutageController < ApplicationController
    #include IdvSession
    #include StepIndicatorConcern

    # before_action :confirm_two_factor_authenticated

    def show
      session[:skip_vendor_outage] = true
      render :show
    end
  end
end
