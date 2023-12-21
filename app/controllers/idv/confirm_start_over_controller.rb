module Idv
  class ConfirmStartOverController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSession
    include StepIndicatorConcern
    include GoBackHelper

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed

    def index
      @step_indicator_step = requested_letter_before? ? :get_a_letter : :verify_phone_or_address

      analytics.idv_gpo_confirm_start_over_visited
    end

    def before_letter
      @step_indicator_step = requested_letter_before? ? :get_a_letter : :verify_phone_or_address

      analytics.idv_gpo_confirm_start_over_before_letter_visited
    end

    private

    def requested_letter_before?
      current_user&.gpo_verification_pending_profile?
    end
  end
end
