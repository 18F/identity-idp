module Verify
  class StepController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
    before_action :confirm_idv_attempts_allowed

    helper_method :step

    private

    def step_name
      raise NotImplementedError, 'must implement step_name method'
    end

    def increment_step_attempts
      idv_session.step_attempts[step_name] += 1
    end

    def step_attempts_exceeded?
      idv_session.step_attempts[step_name] >= Idv::Attempter.idv_max_attempts
    end

    def confirm_step_allowed
      redirect_to_fail_path if step_attempts_exceeded?
    end

    def redirect_to_fail_path
      flash[:max_attempts_exceeded] = true
      redirect_to verify_fail_path
    end
  end
end
