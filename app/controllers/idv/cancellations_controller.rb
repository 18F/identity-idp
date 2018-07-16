module Idv
  class CancellationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      @presenter = CancellationPresenter.new(step: current_step, view_context: view_context)
    end

    def destroy
      @presenter = CancellationConfirmationPresenter.new
      idv_session = user_session[:idv]
      idv_session&.clear
    end

    private

    def current_step
      params.require(:step).to_sym
    end
  end
end
