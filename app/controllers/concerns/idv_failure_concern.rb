module IdvFailureConcern
  extend ActiveSupport::Concern

  def idv_step_failure_reason
    return :fail if fail?
    return :jobfail if jobfail?
    return :timeout if timeout?
    return :warning if warning?
  end

  def render_idv_step_failure(step, reason)
    return render_failure('shared/_failure', failure_presenter(step)) if reason == :fail
    render_failure('idv/shared/verification_failure', warning_presenter(step, reason))
  end

  def render_failure(template, presenter)
    render_full_width(template, locals: { presenter: presenter })
  end

  private

  def fail?
    idv_attempter.exceeded? || step_attempts_exceeded?
  end

  def jobfail?
    step.vendor_validator_job_failed?
  end

  def timeout?
    !step.vendor_validation_passed? && step.vendor_validation_timed_out?
  end

  def warning?
    !step.vendor_validation_passed? && !step.vendor_validation_timed_out?
  end

  def failure_presenter(step)
    Idv::MaxAttemptsFailurePresenter.new(
      decorated_session: decorated_session,
      step_name: step,
      view_context: view_context
    )
  end

  def warning_presenter(step, reason)
    Idv::WarningPresenter.new(
      reason: reason,
      remaining_attempts: remaining_step_attempts,
      step_name: step,
      view_context: view_context
    )
  end
end
