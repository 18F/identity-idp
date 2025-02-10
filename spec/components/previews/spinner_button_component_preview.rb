class SpinnerButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(SpinnerButtonComponent.new(big: true).with_content('Submit'))
  end

  def with_action_message
    render(
      SpinnerButtonComponent.new(
        big: true,
        action_message: 'Verifying…',
      ).with_content('Submit'),
    )
  end

  def outline
    render(SpinnerButtonComponent.new(big: true, outline: true).with_content('Submit'))
  end

  def outline_with_action_message
    render(
      SpinnerButtonComponent.new(
        big: true,
        outline: true,
        action_message: 'Verifying…',
      ).with_content('Submit'),
    )
  end
  # @!endgroup

  # @param action_message text
  # @param outline toggle
  # @param wide toggle
  # @param full_width toggle
  def workbench(action_message: nil, outline: false, wide: false, full_width: false)
    render(
      SpinnerButtonComponent.new(
        big: true,
        outline:,
        wide:,
        full_width:,
        **{ action_message: }.compact,
      ).with_content('Submit'),
    )
  end
end
