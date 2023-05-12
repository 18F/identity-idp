module Idv
  class GpoConfirmCancelController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include GoBackHelper
    
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def index
      # TODO: New analytics event?
      # analytics.idv_cancellation_visited(step: params[:step], **properties)
      @go_back_path = idv_session.go_back_path || idv_path
    end

  end
end
