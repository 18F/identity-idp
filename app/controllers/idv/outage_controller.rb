module Idv
  class OutageController < ApplicationController
    include IdvSession
    include StepIndicatorConcern

    before_action :confirm_two_factor_authenticated

    def show
      session[:skip_vendor_outage] = true
      render :show, locals: { current_sp:, exit_url: }
    end

    def exit_url
      current_sp&.return_to_sp_url || account_path
    end
  end
end
