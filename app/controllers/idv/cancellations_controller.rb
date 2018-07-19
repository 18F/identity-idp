module Idv
  class CancellationsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def new
      analytics.track_event(Analytics::IDV_CANCELLATION)
      @presenter = CancellationPresenter.new(view_context: view_context)
    end

    def destroy
      analytics.track_event(Analytics::IDV_CANCELLATION_CONFIRMED)
      @presenter = CancellationConfirmationPresenter.new
      idv_session = user_session[:idv]
      idv_session&.clear
    end
  end
end
