module Idv
  class DocAuthController < ApplicationController
    def index
      log_unexpected_visit('DocAuthController index')

      redirect_to idv_welcome_url
    end

    def show
      log_unexpected_visit('DocAuthController show')

      redirect_to idv_welcome_url
    end

    def update
      log_unexpected_visit('DocAuthController update')

      redirect_to idv_welcome_url
    end

    def return_to_sp
      log_unexpected_visit('DocAuthController return_to_sp', location: params[:location])
      redirect_to return_to_sp_failure_to_proof_url(
        step: params[:step],
        location: params[:location],
      )
    end

    # Temporary logging to see if we're using these routes anywhere
    def log_unexpected_visit(from, **extra)
      extra[:referer] = request.referer
      extra[:step] = params[:step]
      analytics.track_event(from, **extra)
    end
  end
end
