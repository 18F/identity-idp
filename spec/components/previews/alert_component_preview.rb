class AlertComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(AlertComponent.new(message: 'A default message'))
  end

  def info
    render(AlertComponent.new(message: 'An info message', type: :info))
  end

  def success
    render(AlertComponent.new(message: 'A success message', type: :success))
  end

  def warning
    render(AlertComponent.new(message: 'A warning message', type: :warning))
  end

  def error
    render(AlertComponent.new(message: 'An error message', type: :error))
  end

  def emergency
    render(AlertComponent.new(message: 'An emergency message', type: :emergency))
  end

  def with_custom_text_tag
    render(AlertComponent.new(type: :success, message: 'A custom message', text_tag: 'div'))
  end
  # @!endgroup

  # @param message text
  # @param type select [~, info, success, warning, error, emergency]
  def workbench(message: 'An important message', type: nil)
    render(AlertComponent.new(message:, type: type&.to_sym))
  end
end
