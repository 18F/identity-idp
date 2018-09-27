module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
  end

  private

  def remaining_step_attempts
    Idv::Attempter.idv_max_attempts - idv_session.step_attempts[step_name]
  end

  def step_attempts_exceeded?
    idv_session.step_attempts[step_name] >= Idv::Attempter.idv_max_attempts
  end

  def confirm_step_allowed
    redirect_to_fail_url if step_attempts_exceeded?
  end

  def redirect_to_fail_url
    redirect_to failure_url(:fail)
  end
end
