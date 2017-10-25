module IdvFailureConcern
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/MethodLength
  def render_failure
    if step_attempts_exceeded?
      @view_model = view_model(error: 'fail')
      flash_message(type: :error)
    elsif step.vendor_validator_job_failed?
      @view_model = view_model(error: 'jobfail')
      flash_message(type: :warning)
    elsif form_valid_but_vendor_validation_failed?
      @view_model = view_model(error: 'warning', timed_out: step.vendor_validation_timed_out?)
      flash_message(type: :warning)
    else
      @view_model = view_model
    end
  end
  # rubocop:enable Metrics/MethodLength

  def form_valid_but_vendor_validation_failed?
    idv_form.valid? && !step.vendor_validation_passed?
  end

  def flash_message(type:)
    flash.now[type.to_sym] = @view_model.flash_message
  end

  def view_model(error: nil, timed_out: nil)
    view_model_class.new(
      error: error,
      remaining_attempts: remaining_step_attempts,
      idv_form: idv_form,
      timed_out: timed_out
    )
  end
end
