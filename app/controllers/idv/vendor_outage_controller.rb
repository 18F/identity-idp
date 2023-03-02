module Idv
  class VendorOutageController < ApplicationController
    #include IdvSession
    #include StepIndicatorConcern

    # before_action :confirm_two_factor_authenticated

    def show
      render :show
    end
  end
end
