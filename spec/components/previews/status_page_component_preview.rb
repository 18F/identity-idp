class StatusPageComponentPreview < BaseComponentPreview
  # @!group Preview
  def error
    render(StatusPageComponent.new(status: :error).with_content(example_long_content))
  end

  def error_with_lock_icon
    render(StatusPageComponent.new(status: :error, icon: :lock).with_content(example_long_content))
  end

  def warning
    render(StatusPageComponent.new(status: :warning).with_content(example_long_content))
  end

  def info_with_question_icon
    render(
      StatusPageComponent.new(status: :info, icon: :question).with_content(example_long_content),
    )
  end
  # @!endgroup

  # @param status select [~,info,warning,error]
  # @param icon select [~,question,lock]
  def workbench(status: 'error', icon: nil)
    render(
      StatusPageComponent.new(
        status: status.to_sym,
        **{ icon: icon&.to_sym }.compact,
      ).with_content(example_long_content),
    )
  end
end
