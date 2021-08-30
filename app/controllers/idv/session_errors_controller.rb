module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession
    include EffectiveUser

    before_action :confirm_two_factor_authenticated_or_user_id_in_session
    before_action :confirm_idv_session_step_needed

    def warning
      @remaining_step_attempts = remaining_step_attempts
    end

    def ssn_failure
      render 'idv/session_errors/failure'
    end

    private

    def remaining_step_attempts
      Throttle.for(
        user: effective_user,
        throttle_type: :idv_resolution,
      ).remaining_count
    end

    def confirm_two_factor_authenticated_or_user_id_in_session
      return if session[:doc_capture_user_id].present?

      confirm_two_factor_authenticated
    end

    def confirm_idv_session_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end
  end
end
