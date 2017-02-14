module IdvStepConcern
  extend ActiveSupport::Concern

  include IdvSession

  included do
    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_idv_session_started

    helper_method :step
  end

  private

  def increment_step_attempts
    idv_session.step_attempts[step_name] += 1
  end

  def show_vendor_fail
    @view_model = Object.const_get("#{step_name.capitalize}New").new(modal: 'fail')
    @presenter = VerificationPresenter.new(step_name, @view_model.modal_type)
    flash.now[:error] = @presenter.fail_message
  end

  def show_vendor_warning
    @view_model = Object.const_get("#{step_name.capitalize}New").new(modal: 'warning')
    @presenter = VerificationPresenter.new(
      step_name, @view_model.modal_type, remaining_step_attempts: remaining_step_attempts
    )
    flash.now[:warning] = @presenter.warning_message
  end

  def remaining_step_attempts
    Idv::Attempter.idv_max_attempts - idv_session.step_attempts[step_name]
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
