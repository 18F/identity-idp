module IdvFailureConcern
  extend ActiveSupport::Concern

  def render_failure
    if step_attempts_exceeded?
      @view_model = view_model(error: 'fail')
      flash_message(type: :error)
    elsif form_valid_but_vendor_validation_failed?
      @view_model = view_model(error: 'warning')
      flash_message(type: :warning)
    else
      @view_model = view_model
    end
  end

  def form_valid_but_vendor_validation_failed?
    idv_form.valid? && !step.vendor_validation_passed?
  end

  def flash_message(type:)
    flash.now[type.to_sym] = @view_model.flash_message
  end
end
