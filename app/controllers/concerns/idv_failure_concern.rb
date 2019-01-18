module IdvFailureConcern
  extend ActiveSupport::Concern

  def render_idv_step_failure(step, reason)
    return render_failure('shared/_failure', failure_presenter(step)) if reason == :fail
    render_failure('idv/shared/verification_failure', warning_presenter(step, reason))
  end

  def render_failure(template, presenter)
    render_full_width(template, locals: { presenter: presenter })
  end

  private

  def failure_presenter(step)
    Idv::MaxAttemptsFailurePresenter.new(
      decorated_session: decorated_session,
      step_name: step,
      view_context: view_context,
    )
  end

  def warning_presenter(step, reason)
    Idv::WarningPresenter.new(
      reason: reason,
      remaining_attempts: remaining_step_attempts,
      step_name: step,
      view_context: view_context,
    )
  end
end
