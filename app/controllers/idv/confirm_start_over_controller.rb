module Idv
  class ConfirmStartOverController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include GoBackHelper

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def index
      @current_step = requested_letter_before? ? :get_a_letter : :verify_phone_or_address
      analytics.idv_gpo_confirm_start_over_visited
    end

    private

    def requested_letter_before?
      current_user&.gpo_verification_pending_profile?
    end
  end
end
