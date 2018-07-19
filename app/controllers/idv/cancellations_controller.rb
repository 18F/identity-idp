module Idv
  class CancellationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      # TODO analytics
      @presenter = CancellationPresenter.new(view_context: view_context)
    end

    def destroy
      # TODO analytics
      @presenter = CancellationConfirmationPresenter.new
      idv_session = user_session[:idv]
      idv_session&.clear
    end
  end
end
