class SpinnerButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(SpinnerButtonComponent.new(big: true).with_content('Submit'))
  end

  def action_message
    render(
      SpinnerButtonComponent.new(
        big: true,
        action_message: 'Verifying…',
      ).with_content('Submit'),
    )
  end
  # @!endgroup

  # @param action_message text
  # @param wide toggle
  # @param full_width toggle
  def workbench(action_message: nil, wide: false, full_width: false)
    render(
      SpinnerButtonComponent.new(
        big: true,
        wide:,
        full_width:,
        **{ action_message: }.compact,
      ).with_content('Submit'),
    )
  end
end
