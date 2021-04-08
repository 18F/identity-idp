module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started
  end

  private

  def idv_max_attempts
    Throttle::THROTTLE_CONFIG[:idv_resolution][:max_attempts]
  end

  def step_attempts_exceeded?
    idv_session.step_attempts[step_name] >= idv_max_attempts
  end

  def confirm_step_allowed
    if step_attempts_exceeded?
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_resolution,
        step_name: step_name,
      )
      redirect_to_fail_url
    end
  end

  def redirect_to_fail_url
    redirect_to failure_url(:fail)
  end
end
