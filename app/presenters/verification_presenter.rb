class VerificationPresenter
  include Rails.application.routes.url_helpers

  def initialize(step_name, type, remaining_step_attempts: nil)
    @step_name = step_name
    @type = type
    @remaining_step_attempts = remaining_step_attempts
  end

  def fail_message
    heading + message
  end

  def warning_message
    heading + message + attempts
  end

  def message
    msg = I18n.t("idv.modal.#{step_name}.#{type}")
    helper.content_tag(:p, helper.safe_join([msg.html_safe]))
  end

  def button
    css_classes = 'btn btn-wide px2 py1 rounded-lg border bw2'
    link_text = I18n.t("idv.modal.button.#{type}")

    if type == 'warning'
      helper.link_to link_text, 'javascript:void(0)', id: 'js-close-modal', class: css_classes
    else
      helper.link_to link_text, profile_path, class: css_classes
    end
  end

  private

  attr_reader :step_name, :type, :remaining_step_attempts

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

  def heading
    helper.content_tag(:p, I18n.t("idv.modal.#{step_name}.heading"), class: 'mb2 fs-20p')
  end
end
