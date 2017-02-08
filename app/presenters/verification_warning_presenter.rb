class VerificationWarningPresenter
  def initialize(name, remaining_step_attempts)
    @name = name
    @remaining_step_attempts = remaining_step_attempts
  end

  def warning_message
    I18n.t('idv.modal.warning_html', heading: heading, attempt: attempt, body: body)
  end

  private

  attr_reader :name, :remaining_step_attempts

  def attempt
    I18n.t('idv.modal.attempts', count: remaining_step_attempts)
  end

  def body
    ActionController::Base.helpers.content_tag(:span, I18n.t("idv.modal.#{name}.body"))
  end

  def heading
    ActionController::Base.helpers.content_tag(:strong, I18n.t("idv.modal.#{name}.heading"))
  end
end
