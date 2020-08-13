module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated_or_recovery
    before_action :confirm_idv_session_step_needed

    def warning
      @remaining_step_attempts = remaining_step_attempts
    end

    def failure; end

    private

    def remaining_step_attempts
      Throttler::RemainingCount.call(user_id, :idv_resolution)
    end

    def confirm_two_factor_authenticated_or_recovery
      return if session[:ial2_recovery_user_id].present?
      confirm_two_factor_authenticated
    end

    def confirm_idv_session_step_needed
      return unless user_fully_authenticated?
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end

    def user_id
      ial2_recovery_user_id = session[:ial2_recovery_user_id]
      return ial2_recovery_user_id if ial2_recovery_user_id.present?
      current_user.id
    end
  end
end
