class VerificationWarningPresenter
  def initialize(name, remaining_step_attempts)
    @name = name
    @remaining_step_attempts = remaining_step_attempts
  end

  def warning_message
    heading + warning + attempts
  end

  private

  attr_reader :name, :remaining_step_attempts

  def helper
    ActionController::Base.helpers
  end

  def attempts
    msg = I18n.t('idv.modal.attempts_html', attempt: I18n.t(
      'idv.modal.attempts',
      count: remaining_step_attempts
    ))

    helper.content_tag(:p, helper.safe_join([msg.html_safe]))
  end

  def warning
    helper.content_tag(:p, I18n.t("idv.modal.#{name}.warning"))
  end

  def heading
    helper.content_tag(:p, I18n.t("idv.modal.#{name}.heading"), class: 'mb2 fs-20p')
  end
end
