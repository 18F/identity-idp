module Idv
  class SessionErrorsController < ApplicationController
    include IdvSession

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

    def confirm_idv_session_step_needed
      redirect_to idv_phone_url if idv_session.profile_confirmation == true
    end

    def remaining_step_attempts
      Throttler::RemainingCount.call(current_user.id, :idv_resolution)
    end
  end
end
