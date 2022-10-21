class SpinnerButtonComponentPreview < BaseComponentPreview
  # @!group Kitchen Sink
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

  # @display form true
  # @param action_message text
  def playground(action_message: nil)
    render(
      SpinnerButtonComponent.new(
        form: form_builder,
        big: true,
        **{ action_message: action_message }.compact,
      ).with_content('Submit'),
    )
  end
end
