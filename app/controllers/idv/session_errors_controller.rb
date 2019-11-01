module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated_or_recovery
    before_action :confirm_idv_session_step_needed

    def warning
      @remaining_step_attempts = remaining_step_attempts
    end

    def timeout
      @remaining_step_attempts = remaining_step_attempts
    end

    def jobfail
      @remaining_step_attempts = remaining_step_attempts
    end

    def failure; end

    private

    def confirm_two_factor_authenticated_or_recovery
      user_signed_in? || session[:ial2_recovery_user_id].present?
    end

    def confirm_idv_session_step_needed
      return unless user_signed_in?
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end

    def remaining_step_attempts
      Throttler::RemainingCount.call(user_id, :idv_resolution)
    end

    def user_id
      if user_signed_in?
        current_user.id
      else
        session[:ial2_recovery_user_id]
      end
    end
  end
end
