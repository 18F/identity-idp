module Idv
  class ConfirmStartOverController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include GoBackHelper

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def index
      analytics.idv_gpo_confirm_start_over_visited
    end
  end
end
