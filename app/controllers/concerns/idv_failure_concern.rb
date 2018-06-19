module IdvFailureConcern
  extend ActiveSupport::Concern

  def idv_step_failure_reason
    if idv_attempter.exceeded? || step_attempts_exceeded?
      :fail
    elsif step.vendor_validator_job_failed?
      :jobfail
    elsif !step.vendor_validation_passed?
      step.vendor_validation_timed_out? ? :timeout : :warning
    end
  end

  def render_idv_step_failure(step, reason)
    case reason
    when :fail
      presenter = Idv::MaxAttemptsFailurePresenter.new(
        decorated_session: decorated_session,
        step_name: step,
        view_context: view_context
      )
      render_failure('shared/_failure', presenter)
    when :jobfail, :timeout, :warning
      presenter = Idv::WarningPresenter.new(
        reason: reason,
        remaining_attempts: remaining_step_attempts,
        step_name: step,
        view_context: view_context
      )
      render_failure('idv/shared/other_failure', presenter)
    end
  end

  # def form_valid_but_vendor_validation_failed?
  #   idv_form.valid? && !step.vendor_validation_passed?
  # end

  # def view_model(error: nil, timed_out: nil)
  #   view_model_class.new(
  #     error: error,
  #     remaining_attempts: remaining_step_attempts,
  #     idv_form: idv_form,
  #     timed_out: timed_out
  #   )
  # end

  def render_failure(template, presenter)
    render_full_width(template, locals: { presenter: presenter })
  end
end
